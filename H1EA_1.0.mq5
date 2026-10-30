//+------------------------------------------------------------------+
//| Project: H1EA                                                    |
//| File: H1EA_1.0.mq5                                               |
//| Version: 1.0                                                     |
//| Modified: 2026-10-30 17:53:00                                    |
//| Change: 1.0.10 — Состояние висящего ложного пробоя отделено от следующей свечи CandleTimeframe. |
//| Journal: 1.0.1 2026-10-29 16:16:40 — Поглощение на закрытой свече графика. Бай 233 под low, селл 234 над high, отступ 3*_Point. Print/Alert/Push через SendSignal. Сделок нет. |
//| Journal: 1.0.2 2026-10-29 17:19:01 — Поглощение: бар 2 додж (close==open) тоже считается. Лонг: close2<=open2 и прежние три сравнения бай. Селл: close2>=open2 и прежние три сравнения селл. Бар 1 додж не считается. |
//| Journal: 1.0.3 2026-10-29 18:05:09 — Удалены пустые строки исходника. |
//| Journal: 1.0.4 2026-10-29 19:16:20 — Ложное пробитие: хвост бара 2 и close бара 1. High 221 угол 90 зелёная якорь сверху high1+3*_Point. Low 222 угол 90 красная якорь снизу low1-3*_Point. Оба уровня — только High. Флаг общий с пробитием. |
//| Journal: 1.0.5 2026-10-30 12:17:52 — Ложное пробитие: первая скобка хвост бара 2, вторая хвост бара 1. При загрузке стрелки на истории, 250 закрытых баров графика. OBJPROP_WIDTH 2. |
//| Journal: 1.0.6 2026-10-30 14:46:48 — Удалены пустые строки исходника. |
//| Journal: 1.0.7 2026-10-30 14:55:44 — Подтверждение ложного пробоя следующим баром. Неподтверждённая стрелка удаляется. Настоящее пробитие гасит висящий ложный. Сигнал и цены нового бара только на подтверждении. |
//| Journal: 1.0.8 2026-10-30 15:24:21 — После отмены ложный пробой этой стороны ищется заново на том же закрытии. |
//| Journal: 1.0.9 2026-10-30 16:11:21 — Линии CandleTimeframe начинаются от времени закрытия свечи. В подписи после пробела цена линии. |
//| Journal: 1.0.10 2026-10-30 17:53:00 — Висящий ложный хранит время и уровень своей свечи CandleTimeframe. Подтверждение старого диапазона не занимает сторону нового; текущий бар затем проверяется по новому уровню. |
//| Full source: file:///Users/techchif/My%20Drive/trading/Trobot/H4/H1EA_1.0.mq5 |
//| TZ: file:///Users/techchif/My%20Drive/trading/Trobot/H4/H1EA_TZ_v1.17.txt |
//| Base: file:///Users/techchif/My%20Drive/trading/Trobot/H4/H4.mq5 |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "H1EA: High/Low выбранного ТФ. Сигнал закрытия и перестроение линий - по ТФ из настроек, пробития - по закрытию текущего графика. Сделок нет. Поглощение — по закрытию текущего графика. Стрелка ложного пробития — на закрытой свече графика."
input group "=== Таймфрейм и отображение ==="
input ENUM_TIMEFRAMES CandleTimeframe = PERIOD_H1;
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
input bool EnableCandleCloseSignal = false;
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
string PREFIX = "H1EA_V10_";
datetime LastChartBarTime = 0;
datetime LastChartCheckBar = 0;
datetime LastEngulfBar = 0;
datetime LastRangeBarTime = 0;
datetime LastRangeCloseSignalBar = 0;
bool RangesBuilt = false;
datetime LastCountdownCandleOpen = 0;
long CountdownBaseRemaining = -1;
ulong CountdownBaseTick = 0;
datetime CountdownBaseCandleOpen = 0;
datetime SignalRangeCandleTime = 0;
bool HighSignalAlreadySent = false;
bool LowSignalAlreadySent = false;
datetime PendingHighBar = 0;
int PendingHighTail = 0;
datetime PendingHighRangeCandleTime = 0;
double PendingHighRangeHigh = 0.0;
datetime PendingLowBar = 0;
int PendingLowTail = 0;
datetime PendingLowRangeCandleTime = 0;
double PendingLowRangeLow = 0.0;
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
      if(StringFind(name, PREFIX + "ENG_") == 0)
         continue;
      if(StringFind(name, PREFIX + "FBH_") == 0)
         continue;
      if(StringFind(name, PREFIX + "FBL_") == 0)
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
      datetime candleClose = iTime(_Symbol, CandleTimeframe, shift - 1);
      if(candleClose <= candleTime)
         continue;
      datetime lineEnd = candleClose + lengthSeconds;
      datetime boxEnd = candleTime + lengthSeconds;
      string suffix = IntegerToString((long)candleTime);
      string tfName = GetTimeframeName(CandleTimeframe);
      string highText = tfName + " High " + DoubleToString(highPrice, _Digits);
      string lowText = tfName + " Low " + DoubleToString(lowPrice, _Digits);
      CreateOrUpdateTrendLine(PREFIX + "HIGH_" + suffix,
                              candleClose, lineEnd,
                              highPrice, HighLineColor);
      CreateOrUpdateTrendLine(PREFIX + "LOW_" + suffix,
                              candleClose, lineEnd,
                              lowPrice, LowLineColor);
      CreateOrUpdateLabel(PREFIX + "HTXT_" + suffix,
                          lineEnd, highPrice,
                          highText,
                          HighLineColor);
      CreateOrUpdateLabel(PREFIX + "LTXT_" + suffix,
                          lineEnd, lowPrice,
                          lowText,
                          LowLineColor);
      CreateOrUpdateRectangle(PREFIX + "RECT_" + suffix,
                              candleTime, boxEnd,
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
   int periodSeconds = PeriodSeconds(CandleTimeframe);
   long remaining = 0;
   if(MQLInfoInteger(MQL_TESTER) != 0)
   {
      remaining = (long)candleEnd - (long)TimeCurrent();
      if(remaining < 0)
         remaining = 0;
      if(periodSeconds > 0 && CandleTimeframe != PERIOD_MN1 &&
         remaining > periodSeconds)
         remaining = periodSeconds;
   }
   else
   {
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
      remaining = CountdownBaseRemaining - elapsedSeconds;
      if(remaining < 0)
         remaining = 0;
      if(periodSeconds > 0 && CandleTimeframe != PERIOD_MN1 &&
         remaining > periodSeconds)
      {
         remaining = periodSeconds;
      }
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
// Сигнал закрытия свечи ТФ ИЗ НАСТРОЕК:
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
      CheckClosedRangeCandleSignal();
      UpdateRanges();
   }
   else if(!RangesBuilt)
   {
      UpdateRanges();
   }
}
//--------------------------------------------------------------
// Стрелка ложного пробития. Create не удался — выйти, текст шлёт вызывающий.
//--------------------------------------------------------------
void PlaceFalseBreakArrow(const string name, const datetime barTime, const double price, const int arrowCode, const ENUM_ARROW_ANCHOR anchor, const color clr)
{
   bool placed = false;
   if(ObjectFind(0, name) < 0)
      placed = ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
   else
      placed = ObjectMove(0, name, 0, barTime, price);
   if(!placed)
      return;
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetDouble(0, name, OBJPROP_ANGLE, 90.0);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}
//--------------------------------------------------------------
// Снять стрелку ложного пробоя. Нет объекта — ложь.
//--------------------------------------------------------------
bool DropFalseArrow(const string name)
{
   if(ObjectFind(0, name) < 0)
      return false;
   return ObjectDelete(0, name);
}
//--------------------------------------------------------------
// Бар графика shift против свечи уровня. notify — текст живого бара.
// Ложный пробой: стрелка на находке, сигнал только после подтверждения следующим баром.
//--------------------------------------------------------------
void ApplyClosedBar(const int shift, const datetime barTime, const datetime rangeCandleTime, const double rangeHigh, const double rangeLow, const bool notify)
{
   double chartHigh = iHigh(_Symbol, _Period, shift);
   double chartLow = iLow(_Symbol, _Period, shift);
   double chartClose = iClose(_Symbol, _Period, shift);
   if(chartHigh <= 0.0 || chartLow <= 0.0 || chartClose <= 0.0)
      return;
   if(rangeCandleTime != SignalRangeCandleTime)
   {
      SignalRangeCandleTime = rangeCandleTime;
      HighSignalAlreadySent = false;
      LowSignalAlreadySent = false;
   }
   string rangeTF = "";
   string chartTF = "";
   if(notify)
   {
      rangeTF = GetTimeframeName(CandleTimeframe);
      chartTF = GetTimeframeName((ENUM_TIMEFRAMES)_Period);
   }
   bool paint = false;
   bool skipHigh = false;
   bool skipLow = false;
   datetime bar2Time = iTime(_Symbol, _Period, shift + 1);
   double max2 = 0.0;
   double min2 = 0.0;
   if(bar2Time > 0)
   {
      max2 = iHigh(_Symbol, _Period, shift + 1);
      min2 = iLow(_Symbol, _Period, shift + 1);
   }
   if(PendingHighBar > 0)
   {
      string highName = PREFIX + "FBH_" + IntegerToString((long)PendingHighBar);
      bool highPendingCurrentRange = (PendingHighRangeCandleTime == rangeCandleTime);
      if(bar2Time != PendingHighBar || max2 <= 0.0)
      {
         if(DropFalseArrow(highName))
            paint = true;
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
         skipHigh = true;
      }
      else if(chartClose > PendingHighRangeHigh)
      {
         if(DropFalseArrow(highName))
            paint = true;
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
      }
      else if(max2 < chartHigh)
      {
         if(DropFalseArrow(highName))
            paint = true;
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
      }
      else
      {
         int highTail = PendingHighTail;
         if(highPendingCurrentRange)
            HighSignalAlreadySent = true;
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
         if(notify && EnableFalseBreakoutSignals)
            SendSignal(StringFormat("%s: ЛОЖНОЕ ПРОБИТИЕ HIGH %s. Хвост бара %d %s задел High %s, бар 1 закрылся ниже. Close: %.*f; High: %.*f", _Symbol, rangeTF, highTail, chartTF, rangeTF, _Digits, chartClose, _Digits, chartHigh));
      }
   }
   if(PendingLowBar > 0)
   {
      string lowName = PREFIX + "FBL_" + IntegerToString((long)PendingLowBar);
      bool lowPendingCurrentRange = (PendingLowRangeCandleTime == rangeCandleTime);
      if(bar2Time != PendingLowBar || min2 <= 0.0)
      {
         if(DropFalseArrow(lowName))
            paint = true;
         PendingLowBar = 0;
         PendingLowTail = 0;
         PendingLowRangeCandleTime = 0;
         PendingLowRangeLow = 0.0;
         skipLow = true;
      }
      else if(chartClose < PendingLowRangeLow)
      {
         if(DropFalseArrow(lowName))
            paint = true;
         PendingLowBar = 0;
         PendingLowTail = 0;
         PendingLowRangeCandleTime = 0;
         PendingLowRangeLow = 0.0;
      }
      else if(min2 > chartLow)
      {
         if(DropFalseArrow(lowName))
            paint = true;
         PendingLowBar = 0;
         PendingLowTail = 0;
         PendingLowRangeCandleTime = 0;
         PendingLowRangeLow = 0.0;
      }
      else
      {
         int lowTail = PendingLowTail;
         if(lowPendingCurrentRange)
            LowSignalAlreadySent = true;
         PendingLowBar = 0;
         PendingLowTail = 0;
         PendingLowRangeCandleTime = 0;
         PendingLowRangeLow = 0.0;
         if(notify && EnableFalseBreakoutSignals)
            SendSignal(StringFormat("%s: ЛОЖНОЕ ПРОБИТИЕ LOW %s. Хвост бара %d %s задел Low %s, бар 1 закрылся выше. Close: %.*f; Low: %.*f", _Symbol, rangeTF, lowTail, chartTF, rangeTF, _Digits, chartClose, _Digits, chartLow));
      }
   }
   if(chartClose > rangeHigh && !HighSignalAlreadySent)
   {
      HighSignalAlreadySent = true;
      if(notify && EnableBreakoutSignals)
         SendSignal(StringFormat("%s: ПРОБИТИЕ HIGH %s. Свеча %s впервые закрылась выше High предыдущей %s. Close: %.*f; High: %.*f", _Symbol, rangeTF, chartTF, rangeTF, _Digits, chartClose, _Digits, rangeHigh));
      if(notify && paint)
         ChartRedraw(0);
      return;
   }
   if(chartClose < rangeLow && !LowSignalAlreadySent)
   {
      LowSignalAlreadySent = true;
      if(notify && EnableBreakoutSignals)
         SendSignal(StringFormat("%s: ПРОБИТИЕ LOW %s. Свеча %s впервые закрылась ниже Low предыдущей %s. Close: %.*f; Low: %.*f", _Symbol, rangeTF, chartTF, rangeTF, _Digits, chartClose, _Digits, rangeLow));
      if(notify && paint)
         ChartRedraw(0);
      return;
   }
   if(max2 <= 0.0 || min2 <= 0.0)
   {
      if(notify && paint)
         ChartRedraw(0);
      return;
   }
   bool highByBar2 = (max2 >= rangeHigh && chartClose < rangeHigh);
   bool highByBar1 = (max2 < rangeHigh && chartHigh >= rangeHigh && chartClose < rangeHigh);
   if(!skipHigh && !HighSignalAlreadySent && (highByBar2 || highByBar1))
   {
      if(EnableFalseBreakoutSignals)
      {
         PlaceFalseBreakArrow(PREFIX + "FBH_" + IntegerToString((long)barTime), barTime, chartHigh + 3.0 * _Point, 222, ANCHOR_BOTTOM, clrRed);
         paint = true;
      }
      PendingHighBar = barTime;
      PendingHighTail = 1;
      PendingHighRangeCandleTime = rangeCandleTime;
      PendingHighRangeHigh = rangeHigh;
      if(highByBar2)
         PendingHighTail = 2;
      if(notify && paint)
         ChartRedraw(0);
      return;
   }
   bool lowByBar2 = (min2 <= rangeLow && chartClose > rangeLow);
   bool lowByBar1 = (min2 > rangeLow && chartLow <= rangeLow && chartClose > rangeLow);
   if(!skipLow && !LowSignalAlreadySent && (lowByBar2 || lowByBar1))
   {
      if(EnableFalseBreakoutSignals)
      {
         PlaceFalseBreakArrow(PREFIX + "FBL_" + IntegerToString((long)barTime), barTime, chartLow - 3.0 * _Point, 221, ANCHOR_TOP, clrGreen);
         paint = true;
      }
      PendingLowBar = barTime;
      PendingLowTail = 1;
      PendingLowRangeCandleTime = rangeCandleTime;
      PendingLowRangeLow = rangeLow;
      if(lowByBar2)
         PendingLowTail = 2;
   }
   if(notify && paint)
      ChartRedraw(0);
}
//--------------------------------------------------------------
// Пробития по закрытой свече текущего графика
//--------------------------------------------------------------
void CheckClosedChartCandleSignals()
{
   if(Bars(_Symbol, _Period) < 3)
      return;
   datetime barTime = iTime(_Symbol, _Period, 1);
   if(barTime <= 0)
      return;
   if(barTime == LastChartCheckBar)
      return;
   LastChartCheckBar = barTime;
   if(Bars(_Symbol, CandleTimeframe) < 2)
      return;
   datetime rangeCandleTime = iTime(_Symbol, CandleTimeframe, 1);
   double rangeHigh = iHigh(_Symbol, CandleTimeframe, 1);
   double rangeLow = iLow(_Symbol, CandleTimeframe, 1);
   if(rangeCandleTime <= 0 || rangeHigh <= 0.0 || rangeLow <= 0.0 || rangeHigh < rangeLow)
      return;
   ApplyClosedBar(1, barTime, rangeCandleTime, rangeHigh, rangeLow, true);
}
//--------------------------------------------------------------
// Ложные пробои на истории при загрузке. Текст не шлётся.
//--------------------------------------------------------------
void ScanFalseBreakoutHistory()
{
   PendingHighBar = 0;
   PendingHighTail = 0;
   PendingHighRangeCandleTime = 0;
   PendingHighRangeHigh = 0.0;
   PendingLowBar = 0;
   PendingLowTail = 0;
   PendingLowRangeCandleTime = 0;
   PendingLowRangeLow = 0.0;
   int historyLimit = 250;
   int available = Bars(_Symbol, _Period);
   int oldest = available - 2;
   if(oldest > historyLimit)
      oldest = historyLimit;
   if(oldest < 1)
      return;
   for(int shift = oldest; shift >= 1; shift--)
   {
      datetime barTime = iTime(_Symbol, _Period, shift);
      if(barTime <= 0)
         continue;
      datetime closeTime = iTime(_Symbol, _Period, shift - 1);
      if(closeTime <= 0)
         continue;
      int holding = iBarShift(_Symbol, CandleTimeframe, closeTime, false);
      if(holding < 0)
         continue;
      int closedShift = holding + 1;
      datetime rangeCandleTime = iTime(_Symbol, CandleTimeframe, closedShift);
      double rangeHigh = iHigh(_Symbol, CandleTimeframe, closedShift);
      double rangeLow = iLow(_Symbol, CandleTimeframe, closedShift);
      if(rangeCandleTime <= 0 || rangeHigh <= 0.0 || rangeLow <= 0.0 || rangeHigh < rangeLow)
         continue;
      ApplyClosedBar(shift, barTime, rangeCandleTime, rangeHigh, rangeLow, false);
   }
   ChartRedraw(0);
}
//--------------------------------------------------------------
// Поглощение: две закрытые свечи графика. Бар 1 = shift 1, бар 2 = shift 2.
//--------------------------------------------------------------
void CheckEngulfing()
{
   datetime bar1Time = iTime(_Symbol, _Period, 1);
   if(bar1Time <= 0)
      return;
   if(bar1Time == LastEngulfBar)
      return;
   LastEngulfBar = bar1Time;
   if(Bars(_Symbol, _Period) < 3)
      return;
   datetime bar2Time = iTime(_Symbol, _Period, 2);
   if(bar2Time <= 0)
      return;
   double open1 = iOpen(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double open2 = iOpen(_Symbol, _Period, 2);
   double high2 = iHigh(_Symbol, _Period, 2);
   double low2 = iLow(_Symbol, _Period, 2);
   double close2 = iClose(_Symbol, _Period, 2);
   if(open1 <= 0 || high1 <= 0 || low1 <= 0 || close1 <= 0)
      return;
   if(open2 <= 0 || high2 <= 0 || low2 <= 0 || close2 <= 0)
      return;
   if(high1 < low1 || high1 < open1 || high1 < close1 || low1 > open1 || low1 > close1)
      return;
   if(high2 < low2 || high2 < open2 || high2 < close2 || low2 > open2 || low2 > close2)
      return;
   bool buy = (close2 <= open2 && close1 > open1 && high1 > high2 && close1 > high2);
   bool sell = (close2 >= open2 && close1 < open1 && low1 < low2 && close1 < low2);
   if(buy && sell)
      return;
   if(!buy && !sell)
      return;
   double arrowPrice = low1 - 3.0 * _Point;
   if(!buy)
      arrowPrice = high1 + 3.0 * _Point;
   string name = PREFIX + "ENG_" + IntegerToString((long)bar1Time) + "S";
   if(buy)
      name = PREFIX + "ENG_" + IntegerToString((long)bar1Time) + "B";
   bool created = false;
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_ARROW, 0, bar1Time, arrowPrice))
         return;
      created = true;
   }
   else
      ObjectMove(0, name, 0, bar1Time, arrowPrice);
   if(buy)
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 234);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
   }
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   if(!created)
      return;
   string chartTF = GetTimeframeName((ENUM_TIMEFRAMES)_Period);
   if(buy)
      SendSignal(StringFormat("%s: Поглощение бай %s. Close: %.*f", _Symbol, chartTF, _Digits, close1));
   else
      SendSignal(StringFormat("%s: Поглощение селл %s. Close: %.*f", _Symbol, chartTF, _Digits, close1));
   ChartRedraw(0);
}
//--------------------------------------------------------------
// Проверка новой свечи текущего графика (пробития и поглощение)
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
      CheckEngulfing();
   }
}
//--------------------------------------------------------------
// Инициализация советника
//--------------------------------------------------------------
int OnInit()
{
   LastChartBarTime = iTime(_Symbol, _Period, 0);
   LastChartCheckBar = iTime(_Symbol, _Period, 1);
   LastEngulfBar = iTime(_Symbol, _Period, 1);
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
   ScanFalseBreakoutHistory();
   ResetLastError();
   if(!EventSetTimer(1))
   {
      Print("Ошибка запуска таймера: ", GetLastError());
      return INIT_FAILED;
   }
   Print("H1EA v1.0 запущен. Диапазон, сигнал закрытия и перестроение линий: ",
         GetTimeframeName(CandleTimeframe),
         "; пробития, ложное пробитие двух свечей и поглощение по закрытию графика: ",
         GetTimeframeName((ENUM_TIMEFRAMES)_Period));
   return INIT_SUCCEEDED;
}
//--------------------------------------------------------------
// Удаление объектов при снятии советника
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
// Тик
//--------------------------------------------------------------
void OnTick()
{
   CheckForNewRangeCandle();
   CheckForNewChartCandle();
   UpdateCountdown();
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
