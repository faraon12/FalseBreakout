//+------------------------------------------------------------------+
//|                                        H4_High_Low_v5.16_MT5.mq5 |
//| v5.16: сигнал закрытия свечи и перестроение линий привязаны к ТФ  |
//| из настроек (CandleTimeframe), а не к ТФ текущего графика.        |
//| Пробития/ложные пробития по-прежнему по закрытию свечи графика.   |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0
#property version   "5.16"
#property description "High/Low выбранного ТФ. Сигнал закрытия и перестроение линий - по ТФ из настроек, пробития - по закрытию текущего графика"

input group "=== Таймфрейм и отображение ==="
input ENUM_TIMEFRAMES CandleTimeframe = PERIOD_H4;
input int CandlesBack = 5;
input int LineLengthBars = 6;
input bool ShowLabels = true;
input bool ShowRangeRectangles = true;

input group "=== Цвета и линии ==="
input color HighLineColor = clrRed;
input color LowLineColor = clrGreen;
input color RangeFillColor = clrAliceBlue;
input int LineWidth = 1;
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;

input group "=== Сигналы ==="
input bool EnableCandleCloseSignal = false;   // сигнал закрытия свечи ТФ из настроек
input bool EnableBreakoutSignals = true;
input bool EnableFalseBreakoutSignals = true;
input bool EnablePopupAlerts = true;
input bool EnablePushNotifications = false;

input group "=== Таймер закрытия свечи выбранного ТФ ==="
input bool ShowCountdown = true;
input ENUM_BASE_CORNER CountdownCorner = CORNER_RIGHT_UPPER;
input int CountdownX = 20;
input int CountdownY = 30;
input color CountdownColor = clrBlack;
input string CountdownFont = "Arial";
input int CountdownFontSize = 12;

//--------------------------------------------------------------
// Глобальные переменные
//--------------------------------------------------------------

string PREFIX = "MTFHL_V515_";

// Текущий график (для пробитий)
datetime LastChartBarTime = 0;        // открытие последней замеченной свечи графика
datetime LastChartCheckBar = 0;       // закрытая свеча графика, для которой уже проверены пробития

// ТФ из настроек (CandleTimeframe): сигнал закрытия и перестроение линий
datetime LastRangeBarTime = 0;        // открытие текущей (формирующейся) свечи ТФ из настроек
datetime LastRangeCloseSignalBar = 0; // закрытая свеча ТФ из настроек, по которой уже был сигнал закрытия
bool RangesBuilt = false;             // линии построены (если нет - пробуем снова, пока не загрузится история)

datetime LastCountdownCandleOpen = 0;

// Таймер
long CountdownBaseRemaining = -1;
ulong CountdownBaseTick = 0;
datetime CountdownBaseCandleOpen = 0;

// Идентификатор диапазона, для которого уже отправлен сигнал.
// Для High и Low используются отдельные отметки.
datetime SignalRangeCandleTime = 0;
bool HighSignalAlreadySent = false;
bool LowSignalAlreadySent = false;

//--------------------------------------------------------------
// Название таймфрейма
//--------------------------------------------------------------

string GetTimeframeName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
   }

   return EnumToString(tf);
}

//--------------------------------------------------------------
// Текущее время терминала
//--------------------------------------------------------------

datetime GetServerTime()
{
   datetime serverTime = TimeTradeServer();

   if(serverTime > 0)
      return serverTime;

   serverTime = TimeCurrent();

   if(serverTime > 0)
      return serverTime;

   return TimeLocal();
}

//--------------------------------------------------------------
// Время закрытия свечи выбранного ТФ
//--------------------------------------------------------------

datetime GetCandleEndTime(datetime candleOpen, ENUM_TIMEFRAMES tf)
{
   if(candleOpen <= 0)
      return 0;

   if(tf == PERIOD_MN1)
   {
      MqlDateTime dt;
      TimeToStruct(candleOpen, dt);

      dt.day = 1;
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;

      dt.mon++;

      if(dt.mon > 12)
      {
         dt.mon = 1;
         dt.year++;
      }

      return StructToTime(dt);
   }

   int seconds = PeriodSeconds(tf);

   if(seconds <= 0)
      return 0;

   return candleOpen + seconds;
}

//--------------------------------------------------------------
// Расчёт начального остатка времени
//--------------------------------------------------------------

long CalculateInitialRemaining(datetime candleOpen,
                               datetime candleEnd)
{
   if(candleOpen <= 0 || candleEnd <= candleOpen)
      return -1;

   datetime now = TimeTradeServer();

   if(now >= candleOpen && now < candleEnd)
      return (long)candleEnd - (long)now;

   now = TimeCurrent();

   if(now >= candleOpen && now < candleEnd)
      return (long)candleEnd - (long)now;

   MqlTick tick;

   if(SymbolInfoTick(_Symbol, tick))
   {
      if(tick.time >= candleOpen && tick.time < candleEnd)
         return (long)candleEnd - (long)tick.time;
   }

   now = TimeLocal();

   if(now >= candleOpen && now < candleEnd)
      return (long)candleEnd - (long)now;

   int periodSeconds = PeriodSeconds(CandleTimeframe);

   if(periodSeconds > 0 && CandleTimeframe != PERIOD_MN1)
   {
      long elapsed = (long)now - (long)candleOpen;
      long position = elapsed % periodSeconds;

      if(position < 0)
         position += periodSeconds;

      long remaining = periodSeconds - position;

      if(remaining < 1)
         remaining = periodSeconds;

      if(remaining > periodSeconds)
         remaining = periodSeconds;

      return remaining;
   }

   long remaining = (long)candleEnd - (long)now;

   if(remaining < 0)
      remaining = 0;

   return remaining;
}

//--------------------------------------------------------------
// Отправка сигнала
//--------------------------------------------------------------

void SendSignal(string message)
{
   Print(message);

   if(EnablePopupAlerts)
      Alert(message);

   if(EnablePushNotifications)
   {
      ResetLastError();

      if(!SendNotification(message))
         Print("Ошибка Push: ", GetLastError());
   }
}

//--------------------------------------------------------------
// Создание или обновление линии
//--------------------------------------------------------------

bool CreateOrUpdateTrendLine(string name,
                             datetime time1,
                             datetime time2,
                             double price,
                             color lineColor)
{
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TREND, 0,
                       time1, price, time2, price))
      {
         Print("Ошибка создания линии: ", name,
               "; код ", GetLastError());
         return false;
      }
   }
   else
   {
      ObjectMove(0, name, 0, time1, price);
      ObjectMove(0, name, 1, time2, price);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   return true;
}

//--------------------------------------------------------------
// Подписи High / Low
//--------------------------------------------------------------

void CreateOrUpdateLabel(string name,
                         datetime time1,
                         double price,
                         string labelText,
                         color labelColor)
{
   if(!ShowLabels)
   {
      ObjectDelete(0, name);
      return;
   }

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, time1, price))
         return;
   }
   else
   {
      ObjectMove(0, name, 0, time1, price);
   }

   ObjectSetString(0, name, OBJPROP_TEXT, labelText);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//--------------------------------------------------------------
// Прямоугольник диапазона
//--------------------------------------------------------------

void CreateOrUpdateRectangle(string name,
                             datetime time1,
                             datetime time2,
                             double highPrice,
                             double lowPrice)
{
   if(!ShowRangeRectangles)
   {
      ObjectDelete(0, name);
      return;
   }

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                       time1, highPrice, time2, lowPrice))
      {
         Print("Ошибка создания диапазона: ", name,
               "; код ", GetLastError());
         return;
      }
   }
   else
   {
      ObjectMove(0, name, 0, time1, highPrice);
      ObjectMove(0, name, 1, time2, lowPrice);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR, RangeFillColor);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//--------------------------------------------------------------
// Очистка старых объектов
//--------------------------------------------------------------

void DeleteObjectsOutsideHistory(int barsToKeep)
{
   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, PREFIX) != 0)
         continue;

      if(StringFind(name, PREFIX + "COUNTDOWN") == 0)
         continue;

      bool keep = false;

      for(int shift = 1; shift <= barsToKeep; shift++)
      {
         datetime candleTime = iTime(_Symbol, CandleTimeframe, shift);

         if(candleTime <= 0)
            continue;

         string suffix = IntegerToString((long)candleTime);

         if(StringFind(name, suffix) >= 0)
         {
            keep = true;
            break;
         }
      }

      if(!keep)
         ObjectDelete(0, name);
   }
}

//--------------------------------------------------------------
// Отображение диапазонов выбранного ТФ.
// Строится по ПОСЛЕДНИМ ЗАКРЫТЫМ свечам ТФ из настроек (shift >= 1).
// Вызывается при закрытии свечи этого ТФ (а также при запуске).
//--------------------------------------------------------------

void UpdateRanges()
{
   int available = Bars(_Symbol, CandleTimeframe);

   if(available < 3)
      return;

   int count = CandlesBack;

   if(count < 1)
      count = 1;

   if(count > available - 1)
      count = available - 1;

   int periodSeconds = PeriodSeconds(CandleTimeframe);

   if(periodSeconds <= 0)
      periodSeconds = 60;

   int lengthBars = LineLengthBars;

   if(lengthBars < 1)
      lengthBars = 1;

   int lengthSeconds = periodSeconds * lengthBars;

   bool built = false;

   for(int shift = 1; shift <= count; shift++)
   {
      datetime candleTime = iTime(_Symbol, CandleTimeframe, shift);

      if(candleTime <= 0)
         continue;

      double highPrice = iHigh(_Symbol, CandleTimeframe, shift);
      double lowPrice  = iLow(_Symbol, CandleTimeframe, shift);

      if(highPrice <= 0 || lowPrice <= 0 || highPrice < lowPrice)
         continue;

      datetime lineEnd = candleTime + lengthSeconds;
      string suffix = IntegerToString((long)candleTime);

      CreateOrUpdateTrendLine(PREFIX + "HIGH_" + suffix,
                              candleTime, lineEnd,
                              highPrice, HighLineColor);

      CreateOrUpdateTrendLine(PREFIX + "LOW_" + suffix,
                              candleTime, lineEnd,
                              lowPrice, LowLineColor);

      CreateOrUpdateLabel(PREFIX + "HTXT_" + suffix,
                          lineEnd, highPrice,
                          GetTimeframeName(CandleTimeframe) + " High",
                          HighLineColor);

      CreateOrUpdateLabel(PREFIX + "LTXT_" + suffix,
                          lineEnd, lowPrice,
                          GetTimeframeName(CandleTimeframe) + " Low",
                          LowLineColor);

      CreateOrUpdateRectangle(PREFIX + "RECT_" + suffix,
                              candleTime, lineEnd,
                              highPrice, lowPrice);

      built = true;
   }

   RangesBuilt = built;

   DeleteObjectsOutsideHistory(count);
   ChartRedraw(0);
}

//--------------------------------------------------------------
// Таймер закрытия выбранной свечи
//--------------------------------------------------------------

void UpdateCountdown()
{
   string name = PREFIX + "COUNTDOWN";

   if(!ShowCountdown)
   {
      ObjectDelete(0, name);
      return;
   }

   datetime candleOpen = iTime(_Symbol, CandleTimeframe, 0);

   if(candleOpen <= 0)
      return;

   datetime candleEnd = GetCandleEndTime(candleOpen, CandleTimeframe);

   if(candleEnd <= candleOpen)
      return;

   if(candleOpen != CountdownBaseCandleOpen ||
      CountdownBaseRemaining < 0)
   {
      CountdownBaseCandleOpen = candleOpen;
      LastCountdownCandleOpen = candleOpen;

      CountdownBaseRemaining =
         CalculateInitialRemaining(candleOpen, candleEnd);

      CountdownBaseTick = GetTickCount64();

      Print("Таймер: новая свеча ",
            GetTimeframeName(CandleTimeframe),
            "; открытие ",
            TimeToString(candleOpen, TIME_DATE | TIME_SECONDS),
            "; начальный остаток: ",
            CountdownBaseRemaining, " сек.");
   }

   ulong currentTick = GetTickCount64();

   long elapsedSeconds =
      (long)((currentTick - CountdownBaseTick) / 1000);

   long remaining = CountdownBaseRemaining - elapsedSeconds;

   if(remaining < 0)
      remaining = 0;

   int periodSeconds = PeriodSeconds(CandleTimeframe);

   if(periodSeconds > 0 && CandleTimeframe != PERIOD_MN1 &&
      remaining > periodSeconds)
   {
      remaining = periodSeconds;
   }

   long hours = remaining / 3600;
   long minutes = (remaining % 3600) / 60;
   long seconds = remaining % 60;

   string timerText;

   if(hours > 0)
   {
      timerText = StringFormat(
         "%s до закрытия: %02d:%02d:%02d",
         GetTimeframeName(CandleTimeframe),
         (int)hours,
         (int)minutes,
         (int)seconds);
   }
   else
   {
      timerText = StringFormat(
         "%s до закрытия: %02d:%02d",
         GetTimeframeName(CandleTimeframe),
         (int)minutes,
         (int)seconds);
   }

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      {
         Print("Не удалось создать объект таймера: ",
               GetLastError());
         return;
      }
   }

   ObjectSetInteger(0, name, OBJPROP_CORNER, CountdownCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, CountdownX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, CountdownY);
   ObjectSetInteger(0, name, OBJPROP_COLOR, CountdownColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, CountdownFontSize);
   ObjectSetString(0, name, OBJPROP_FONT, CountdownFont);
   ObjectSetString(0, name, OBJPROP_TEXT, timerText);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   ChartRedraw(0);
}

//--------------------------------------------------------------
// Сигнал закрытия свечи ТФ ИЗ НАСТРОЕК (например H4):
// срабатывает, когда закрылась свеча CandleTimeframe.
//--------------------------------------------------------------

void CheckClosedRangeCandleSignal()
{
   if(Bars(_Symbol, CandleTimeframe) < 3)
      return;

   datetime closedRangeBarTime = iTime(_Symbol, CandleTimeframe, 1);

   if(closedRangeBarTime <= 0)
      return;

   if(closedRangeBarTime == LastRangeCloseSignalBar)
      return;

   LastRangeCloseSignalBar = closedRangeBarTime;

   double rangeClose = iClose(_Symbol, CandleTimeframe, 1);

   if(rangeClose <= 0)
      return;

   if(EnableCandleCloseSignal)
   {
      SendSignal(StringFormat(
         "%s: свеча %s закрылась. Close: %.*f",
         _Symbol,
         GetTimeframeName(CandleTimeframe),
         _Digits, rangeClose));
   }
}

//--------------------------------------------------------------
// Новая свеча ТФ из настроек: сигнал закрытия + перестроение линий
//--------------------------------------------------------------

void CheckForNewRangeCandle()
{
   datetime currentRangeBarTime = iTime(_Symbol, CandleTimeframe, 0);

   if(currentRangeBarTime <= 0)
      return;

   if(LastRangeBarTime == 0)
   {
      LastRangeBarTime = currentRangeBarTime;
      return;
   }

   if(currentRangeBarTime != LastRangeBarTime)
   {
      LastRangeBarTime = currentRangeBarTime;

      // Закрылась свеча выбранного ТФ
      CheckClosedRangeCandleSignal();

      // Линии перестраиваются по последним закрытым свечам этого же ТФ
      UpdateRanges();
   }
   else if(!RangesBuilt)
   {
      // История ТФ могла ещё не загрузиться при запуске - пробуем снова
      UpdateRanges();
   }
}

//--------------------------------------------------------------
// Пробития по закрытой свече текущего графика
// (сравнение с High/Low последней закрытой свечи ТФ из настроек)
//--------------------------------------------------------------

void CheckClosedChartCandleSignals()
{
   if(Bars(_Symbol, _Period) < 3)
      return;

   datetime closedChartBarTime = iTime(_Symbol, _Period, 1);

   if(closedChartBarTime <= 0)
      return;

   if(closedChartBarTime == LastChartCheckBar)
      return;

   LastChartCheckBar = closedChartBarTime;

   double chartHigh  = iHigh(_Symbol, _Period, 1);
   double chartLow   = iLow(_Symbol, _Period, 1);
   double chartClose = iClose(_Symbol, _Period, 1);

   if(chartHigh <= 0 || chartLow <= 0 || chartClose <= 0)
      return;

   string chartTF = GetTimeframeName((ENUM_TIMEFRAMES)_Period);
   string rangeTF = GetTimeframeName(CandleTimeframe);

   if(Bars(_Symbol, CandleTimeframe) < 2)
      return;

   // Используем именно одну зафиксированную завершённую
   // свечу выбранного таймфрейма как границу диапазона.
   datetime rangeCandleTime = iTime(_Symbol, CandleTimeframe, 1);

   double rangeHigh = iHigh(_Symbol, CandleTimeframe, 1);
   double rangeLow  = iLow(_Symbol, CandleTimeframe, 1);

   if(rangeCandleTime <= 0 ||
      rangeHigh <= 0 || rangeLow <= 0 || rangeHigh < rangeLow)
      return;

   // Смена опорной свечи выбранного ТФ сбрасывает разрешение
   // на один новый сигнал по High и один по Low.
   if(rangeCandleTime != SignalRangeCandleTime)
   {
      SignalRangeCandleTime = rangeCandleTime;
      HighSignalAlreadySent = false;
      LowSignalAlreadySent = false;
   }

   bool breakoutUp = (chartClose > rangeHigh);
   bool breakoutDown = (chartClose < rangeLow);

   bool falseBreakUp = (chartHigh > rangeHigh &&
                        chartClose <= rangeHigh);

   bool falseBreakDown = (chartLow < rangeLow &&
                          chartClose >= rangeLow);

   // Одна закрытая свеча может вызвать только один сигнал.
   // Приоритет пробития — если закрытие за границей,
   // ложное пробитие для этой свечи не отправляем.
   if(breakoutUp && !HighSignalAlreadySent)
   {
      HighSignalAlreadySent = true;

      if(EnableBreakoutSignals)
      {
         SendSignal(StringFormat(
            "%s: ПРОБИТИЕ HIGH %s. Свеча %s впервые закрылась выше High предыдущей %s. Close: %.*f; High: %.*f",
            _Symbol, rangeTF, chartTF, rangeTF,
            _Digits, chartClose, _Digits, rangeHigh));
      }

      return;
   }

   if(breakoutDown && !LowSignalAlreadySent)
   {
      LowSignalAlreadySent = true;

      if(EnableBreakoutSignals)
      {
         SendSignal(StringFormat(
            "%s: ПРОБИТИЕ LOW %s. Свеча %s впервые закрылась ниже Low предыдущей %s. Close: %.*f; Low: %.*f",
            _Symbol, rangeTF, chartTF, rangeTF,
            _Digits, chartClose, _Digits, rangeLow));
      }

      return;
   }

   if(falseBreakUp && !HighSignalAlreadySent)
   {
      HighSignalAlreadySent = true;

      if(EnableFalseBreakoutSignals)
      {
         SendSignal(StringFormat(
            "%s: ЛОЖНОЕ ПРОБИТИЕ HIGH %s. Свеча %s вышла выше High, но закрылась обратно. Close: %.*f; High: %.*f",
            _Symbol, rangeTF, chartTF,
            _Digits, chartClose, _Digits, rangeHigh));
      }

      return;
   }

   if(falseBreakDown && !LowSignalAlreadySent)
   {
      LowSignalAlreadySent = true;

      if(EnableFalseBreakoutSignals)
      {
         SendSignal(StringFormat(
            "%s: ЛОЖНОЕ ПРОБИТИЕ LOW %s. Свеча %s вышла ниже Low, но закрылась обратно. Close: %.*f; Low: %.*f",
            _Symbol, rangeTF, chartTF,
            _Digits, chartClose, _Digits, rangeLow));
      }

      return;
   }
}

//--------------------------------------------------------------
// Проверка новой свечи текущего графика (только пробития)
//--------------------------------------------------------------

void CheckForNewChartCandle()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);

   if(currentBarTime <= 0)
      return;

   if(LastChartBarTime == 0)
   {
      LastChartBarTime = currentBarTime;
      return;
   }

   if(currentBarTime != LastChartBarTime)
   {
      LastChartBarTime = currentBarTime;

      CheckClosedChartCandleSignals();
   }
}

//--------------------------------------------------------------
// Инициализация индикатора
//--------------------------------------------------------------

int OnInit()
{
   IndicatorSetString(
      INDICATOR_SHORTNAME,
      "H4 High Low (" + GetTimeframeName(CandleTimeframe) + ")");

   // Текущий график (пробития)
   LastChartBarTime = iTime(_Symbol, _Period, 0);
   LastChartCheckBar = iTime(_Symbol, _Period, 1);

   // ТФ из настроек (сигнал закрытия и перестроение линий)
   LastRangeBarTime = iTime(_Symbol, CandleTimeframe, 0);
   LastRangeCloseSignalBar = iTime(_Symbol, CandleTimeframe, 1);
   RangesBuilt = false;

   LastCountdownCandleOpen = 0;
   CountdownBaseCandleOpen = 0;
   CountdownBaseRemaining = -1;
   CountdownBaseTick = 0;

   SignalRangeCandleTime = iTime(_Symbol, CandleTimeframe, 1);
   HighSignalAlreadySent = false;
   LowSignalAlreadySent = false;

   UpdateRanges();
   UpdateCountdown();

   ResetLastError();

   if(!EventSetTimer(1))
   {
      Print("Ошибка запуска таймера: ", GetLastError());
      return INIT_FAILED;
   }

   Print("H4_High_Low v5.16 запущен. Диапазон, сигнал закрытия и перестроение линий: ",
         GetTimeframeName(CandleTimeframe),
         "; пробития по закрытию графика: ",
         GetTimeframeName((ENUM_TIMEFRAMES)_Period));

   return INIT_SUCCEEDED;
}

//--------------------------------------------------------------
// Удаление объектов при снятии индикатора
//--------------------------------------------------------------

void OnDeinit(const int reason)
{
   EventKillTimer();

   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, PREFIX) == 0)
         ObjectDelete(0, name);
   }

   ChartRedraw(0);
}

//--------------------------------------------------------------
// Основной расчёт
//--------------------------------------------------------------

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   CheckForNewRangeCandle();
   CheckForNewChartCandle();
   UpdateCountdown();

   return rates_total;
}

//--------------------------------------------------------------
// Таймер — независимое событие MT5
//--------------------------------------------------------------

void OnTimer()
{
   UpdateCountdown();
   CheckForNewRangeCandle();
   CheckForNewChartCandle();
}