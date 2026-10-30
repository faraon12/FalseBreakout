//+------------------------------------------------------------------+
//| Project: H1EA_dbg                                                |
//| File: H1EA_dbg_1.0.mq5                                           |
//| Version: 1.0                                                     |
//| Modified: 2026-10-30 18:26:00                                    |
//| Change: Точечная диагностика FalseBreakHigh XAUUSD M1/M30 за 2026.09.01 00:58:00–01:12:59 без изменения торговой и сигнальной логики. |
//| Full source: file:///Users/techchif/My%20Drive/trading/Trobot/H4/H1EA_dbg_1.0.mq5 |
//| TZ v1.18: file:///Users/techchif/My%20Drive/trading/Trobot/H4/H1EA_TZ_v1.18.txt |
//| Base source: file:///Users/techchif/My%20Drive/trading/Trobot/H4/H1EA_1.0.mq5 |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#define PREFIX DBG_PREFIX
#define PlaceFalseBreakArrow H1EA_BasePlaceFalseBreakArrow
#define DropFalseArrow H1EA_BaseDropFalseArrow
#define ApplyClosedBar H1EA_BaseApplyClosedBar
#define CheckClosedChartCandleSignals H1EA_BaseCheckClosedChartCandleSignals
#define ScanFalseBreakoutHistory H1EA_BaseScanFalseBreakoutHistory
#define CheckForNewChartCandle H1EA_BaseCheckForNewChartCandle
#define OnInit H1EA_BaseOnInit
#define OnDeinit H1EA_BaseOnDeinit
#define OnTick H1EA_BaseOnTick
#define OnTimer H1EA_BaseOnTimer
#include "H1EA.mq5"
#undef OnTimer
#undef OnTick
#undef OnDeinit
#undef OnInit
#undef CheckForNewChartCandle
#undef ScanFalseBreakoutHistory
#undef CheckClosedChartCandleSignals
#undef ApplyClosedBar
#undef DropFalseArrow
#undef PlaceFalseBreakArrow
#undef PREFIX
bool IsDebugBar(const datetime barTime)
{
   return StringFind(_Symbol, "XAUUSD") == 0 && barTime >= D'2026.09.01 00:58:00' && barTime <= D'2026.09.01 01:12:59';
}
string DbgTime(const datetime value)
{
   return TimeToString(value, TIME_DATE | TIME_SECONDS);
}
string DbgPrice(const double value)
{
   return DoubleToString(value, _Digits);
}
void PrintDebugExit(const string path, const datetime barTime)
{
   if(!IsDebugBar(barTime))
      return;
   string currentName = DBG_PREFIX + "FBH_" + IntegerToString((long)barTime);
   bool currentObjectExists = (ObjectFind(0, currentName) >= 0);
   Print("DBG_EXIT path=", path, " HighSignalAlreadySent=", HighSignalAlreadySent, " PendingHighBar=", DbgTime(PendingHighBar), " PendingHighTail=", PendingHighTail, " PendingHighRangeCandleTime=", DbgTime(PendingHighRangeCandleTime), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh), " currentFBH=", currentName, " exists=", currentObjectExists);
}
bool DropFalseArrowDbg(const string name, const string reason, const datetime diagnosticBarTime)
{
   if(ObjectFind(0, name) < 0)
   {
      if(IsDebugBar(diagnosticBarTime))
         Print("DBG_ARROW_DELETE reason=", reason, " name=", name, " exists=false result=false error=0");
      return false;
   }
   ResetLastError();
   bool deleted = ObjectDelete(0, name);
   int errorCode = GetLastError();
   if(IsDebugBar(diagnosticBarTime))
      Print("DBG_ARROW_DELETE reason=", reason, " name=", name, " exists=true result=", deleted, " error=", errorCode);
   return deleted;
}
bool PlaceFalseBreakArrowDbg(const string name, const datetime barTime, const double price, const int arrowCode, const ENUM_ARROW_ANCHOR anchor, const color clr)
{
   bool exists = (ObjectFind(0, name) >= 0);
   ResetLastError();
   bool placed = false;
   if(!exists)
      placed = ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
   else
      placed = ObjectMove(0, name, 0, barTime, price);
   int operationError = GetLastError();
   if(IsDebugBar(barTime))
   {
      if(!exists)
         Print("DBG_ARROW_CREATE name=", name, " result=", placed, " error=", operationError, " barTime=", DbgTime(barTime), " price=", DbgPrice(price));
      else
         Print("DBG_ARROW_MOVE name=", name, " result=", placed, " error=", operationError, " barTime=", DbgTime(barTime), " price=", DbgPrice(price));
   }
   if(!placed)
      return false;
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetDouble(0, name, OBJPROP_ANGLE, 90.0);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   if(IsDebugBar(barTime))
   {
      int found = ObjectFind(0, name);
      datetime actualTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      double actualPrice = ObjectGetDouble(0, name, OBJPROP_PRICE);
      long actualArrowCode = ObjectGetInteger(0, name, OBJPROP_ARROWCODE);
      long actualAnchor = ObjectGetInteger(0, name, OBJPROP_ANCHOR);
      long actualColor = ObjectGetInteger(0, name, OBJPROP_COLOR);
      long actualWidth = ObjectGetInteger(0, name, OBJPROP_WIDTH);
      long actualHidden = ObjectGetInteger(0, name, OBJPROP_HIDDEN);
      long actualBack = ObjectGetInteger(0, name, OBJPROP_BACK);
      Print("DBG_ARROW_STATE name=", name, " ObjectFind=", found, " OBJPROP_TIME=", DbgTime(actualTime), " OBJPROP_PRICE=", DbgPrice(actualPrice), " OBJPROP_ARROWCODE=", actualArrowCode, " OBJPROP_ANCHOR=", actualAnchor, " OBJPROP_COLOR=", actualColor, " OBJPROP_WIDTH=", actualWidth, " OBJPROP_HIDDEN=", actualHidden, " OBJPROP_BACK=", actualBack);
   }
   return true;
}
void ApplyClosedBar(const int shift, const datetime barTime, const datetime rangeCandleTime, const double rangeHigh, const double rangeLow, const bool notify)
{
   double chartOpen = iOpen(_Symbol, _Period, shift);
   double chartHigh = iHigh(_Symbol, _Period, shift);
   double chartLow = iLow(_Symbol, _Period, shift);
   double chartClose = iClose(_Symbol, _Period, shift);
   datetime bar2Time = iTime(_Symbol, _Period, shift + 1);
   double max2 = 0.0;
   double min2 = 0.0;
   if(bar2Time > 0)
   {
      max2 = iHigh(_Symbol, _Period, shift + 1);
      min2 = iLow(_Symbol, _Period, shift + 1);
   }
   bool debugBar = IsDebugBar(barTime);
   if(debugBar)
      Print("DBG_ENTER notify=", notify, " shift=", shift, " barTime=", DbgTime(barTime), " chartOpen=", DbgPrice(chartOpen), " chartHigh=", DbgPrice(chartHigh), " chartLow=", DbgPrice(chartLow), " chartClose=", DbgPrice(chartClose), " bar2Time=", DbgTime(bar2Time), " max2=", DbgPrice(max2), " min2=", DbgPrice(min2), " rangeCandleTime=", DbgTime(rangeCandleTime), " rangeHigh=", DbgPrice(rangeHigh), " rangeLow=", DbgPrice(rangeLow), " SignalRangeCandleTime=", DbgTime(SignalRangeCandleTime), " HighSignalAlreadySent=", HighSignalAlreadySent, " LowSignalAlreadySent=", LowSignalAlreadySent, " PendingHighBar=", DbgTime(PendingHighBar), " PendingHighTail=", PendingHighTail, " PendingHighRangeCandleTime=", DbgTime(PendingHighRangeCandleTime), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh), " PendingLowBar=", DbgTime(PendingLowBar), " PendingLowTail=", PendingLowTail, " PendingLowRangeCandleTime=", DbgTime(PendingLowRangeCandleTime), " PendingLowRangeLow=", DbgPrice(PendingLowRangeLow));
   if(chartHigh <= 0.0 || chartLow <= 0.0 || chartClose <= 0.0)
   {
      PrintDebugExit("INVALID_PRICE", barTime);
      return;
   }
   if(rangeCandleTime != SignalRangeCandleTime)
   {
      datetime oldRangeCandleTime = SignalRangeCandleTime;
      SignalRangeCandleTime = rangeCandleTime;
      HighSignalAlreadySent = false;
      LowSignalAlreadySent = false;
      if(debugBar)
         Print("DBG_RANGE_SWITCH old=", DbgTime(oldRangeCandleTime), " new=", DbgTime(SignalRangeCandleTime), " HighSignalAlreadySent=", HighSignalAlreadySent, " LowSignalAlreadySent=", LowSignalAlreadySent);
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
   if(PendingHighBar > 0)
   {
      string highName = DBG_PREFIX + "FBH_" + IntegerToString((long)PendingHighBar);
      bool highObjectExists = (ObjectFind(0, highName) >= 0);
      bool highPendingCurrentRange = (PendingHighRangeCandleTime == rangeCandleTime);
      if(debugBar)
         Print("DBG_PENDING_HIGH_CHECK name=", highName, " exists=", highObjectExists, " bar2Matches=", (bar2Time == PendingHighBar), " highPendingCurrentRange=", highPendingCurrentRange, " chartClose=", DbgPrice(chartClose), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh), " max2=", DbgPrice(max2), " chartHigh=", DbgPrice(chartHigh));
      if(bar2Time != PendingHighBar || max2 <= 0.0)
      {
         if(debugBar)
            Print("DBG_PENDING_HIGH_DROP_BAR_MISMATCH bar2Time=", DbgTime(bar2Time), " PendingHighBar=", DbgTime(PendingHighBar), " max2=", DbgPrice(max2));
         if(DropFalseArrowDbg(highName, "BAR_MISMATCH", barTime))
            paint = true;
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
         if(debugBar)
            Print("DBG_PENDING_HIGH_CLEARED PendingHighBar=", DbgTime(PendingHighBar), " PendingHighTail=", PendingHighTail, " PendingHighRangeCandleTime=", DbgTime(PendingHighRangeCandleTime), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh));
         skipHigh = true;
      }
      else if(chartClose > PendingHighRangeHigh)
      {
         if(debugBar)
            Print("DBG_PENDING_HIGH_DROP_REAL_BREAK chartClose=", DbgPrice(chartClose), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh));
         if(DropFalseArrowDbg(highName, "REAL_BREAK", barTime))
            paint = true;
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
         if(debugBar)
            Print("DBG_PENDING_HIGH_CLEARED PendingHighBar=", DbgTime(PendingHighBar), " PendingHighTail=", PendingHighTail, " PendingHighRangeCandleTime=", DbgTime(PendingHighRangeCandleTime), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh));
      }
      else if(max2 < chartHigh)
      {
         if(debugBar)
            Print("DBG_PENDING_HIGH_DROP_HIGHER_MAX max2=", DbgPrice(max2), " chartHigh=", DbgPrice(chartHigh));
         if(DropFalseArrowDbg(highName, "HIGHER_MAX", barTime))
            paint = true;
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
         if(debugBar)
            Print("DBG_PENDING_HIGH_CLEARED PendingHighBar=", DbgTime(PendingHighBar), " PendingHighTail=", PendingHighTail, " PendingHighRangeCandleTime=", DbgTime(PendingHighRangeCandleTime), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh));
      }
      else
      {
         int highTail = PendingHighTail;
         bool highFlagWasSet = false;
         if(highPendingCurrentRange)
         {
            HighSignalAlreadySent = true;
            highFlagWasSet = true;
         }
         PendingHighBar = 0;
         PendingHighTail = 0;
         PendingHighRangeCandleTime = 0;
         PendingHighRangeHigh = 0.0;
         if(debugBar)
            Print("DBG_PENDING_HIGH_CONFIRM highTail=", highTail, " highPendingCurrentRange=", highPendingCurrentRange, " HighSignalWasSet=", highFlagWasSet, " HighSignalAlreadySent=", HighSignalAlreadySent, " oldRangeKeptNewFlagFalse=", (!highPendingCurrentRange && !HighSignalAlreadySent), " PendingHighBar=", DbgTime(PendingHighBar), " PendingHighTail=", PendingHighTail, " PendingHighRangeCandleTime=", DbgTime(PendingHighRangeCandleTime), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh));
         if(notify && EnableFalseBreakoutSignals)
            SendSignal(StringFormat("%s: ЛОЖНОЕ ПРОБИТИЕ HIGH %s. Хвост бара %d %s задел High %s, бар 1 закрылся ниже. Close: %.*f; High: %.*f", _Symbol, rangeTF, highTail, chartTF, rangeTF, _Digits, chartClose, _Digits, chartHigh));
      }
   }
   if(PendingLowBar > 0)
   {
      string lowName = DBG_PREFIX + "FBL_" + IntegerToString((long)PendingLowBar);
      bool lowPendingCurrentRange = (PendingLowRangeCandleTime == rangeCandleTime);
      if(bar2Time != PendingLowBar || min2 <= 0.0)
      {
         if(DropFalseArrowDbg(lowName, "LOW_BAR_MISMATCH", barTime))
            paint = true;
         PendingLowBar = 0;
         PendingLowTail = 0;
         PendingLowRangeCandleTime = 0;
         PendingLowRangeLow = 0.0;
         skipLow = true;
      }
      else if(chartClose < PendingLowRangeLow)
      {
         if(DropFalseArrowDbg(lowName, "LOW_REAL_BREAK", barTime))
            paint = true;
         PendingLowBar = 0;
         PendingLowTail = 0;
         PendingLowRangeCandleTime = 0;
         PendingLowRangeLow = 0.0;
      }
      else if(min2 > chartLow)
      {
         if(DropFalseArrowDbg(lowName, "LOWER_MIN", barTime))
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
   bool breakoutUp = (chartClose > rangeHigh && !HighSignalAlreadySent);
   bool breakoutDown = (chartClose < rangeLow && !LowSignalAlreadySent);
   if(debugBar)
      Print("DBG_HIGH_BOOL breakoutUp=", breakoutUp, " breakoutDown=", breakoutDown, " chartClose=", DbgPrice(chartClose), " rangeHigh=", DbgPrice(rangeHigh), " rangeLow=", DbgPrice(rangeLow), " HighSignalAlreadySent=", HighSignalAlreadySent, " LowSignalAlreadySent=", LowSignalAlreadySent);
   if(breakoutUp)
   {
      HighSignalAlreadySent = true;
      if(notify && EnableBreakoutSignals)
         SendSignal(StringFormat("%s: ПРОБИТИЕ HIGH %s. Свеча %s впервые закрылась выше High предыдущей %s. Close: %.*f; High: %.*f", _Symbol, rangeTF, chartTF, rangeTF, _Digits, chartClose, _Digits, rangeHigh));
      if(notify && paint)
         ChartRedraw(0);
      PrintDebugExit("REAL_HIGH", barTime);
      return;
   }
   if(breakoutDown)
   {
      LowSignalAlreadySent = true;
      if(notify && EnableBreakoutSignals)
         SendSignal(StringFormat("%s: ПРОБИТИЕ LOW %s. Свеча %s впервые закрылась ниже Low предыдущей %s. Close: %.*f; Low: %.*f", _Symbol, rangeTF, chartTF, rangeTF, _Digits, chartClose, _Digits, rangeLow));
      if(notify && paint)
         ChartRedraw(0);
      PrintDebugExit("REAL_LOW", barTime);
      return;
   }
   if(max2 <= 0.0 || min2 <= 0.0)
   {
      if(debugBar)
         Print("DBG_FALSE_HIGH_BOOL skipHigh=", skipHigh, " HighSignalAlreadySent=", HighSignalAlreadySent, " max2=", DbgPrice(max2), " rangeHigh=", DbgPrice(rangeHigh), " chartHigh=", DbgPrice(chartHigh), " chartClose=", DbgPrice(chartClose), " highByBar2=false highByBar1=false enter=false");
      if(debugBar)
         Print("DBG_FALSE_HIGH_SKIP_NO_BAR2_DATA bar2Time=", DbgTime(bar2Time), " max2=", DbgPrice(max2), " min2=", DbgPrice(min2));
      if(notify && paint)
         ChartRedraw(0);
      PrintDebugExit("NO_BAR2", barTime);
      return;
   }
   bool highByBar2 = (max2 >= rangeHigh && chartClose < rangeHigh);
   bool highByBar1 = (max2 < rangeHigh && chartHigh >= rangeHigh && chartClose < rangeHigh);
   bool falseHighEnter = (!skipHigh && !HighSignalAlreadySent && (highByBar2 || highByBar1));
   if(debugBar)
      Print("DBG_FALSE_HIGH_BOOL skipHigh=", skipHigh, " HighSignalAlreadySent=", HighSignalAlreadySent, " max2=", DbgPrice(max2), " rangeHigh=", DbgPrice(rangeHigh), " chartHigh=", DbgPrice(chartHigh), " chartClose=", DbgPrice(chartClose), " highByBar2=", highByBar2, " highByBar1=", highByBar1, " enter=", falseHighEnter);
   if(!falseHighEnter)
   {
      if(debugBar && skipHigh)
         Print("DBG_FALSE_HIGH_SKIP_SKIP_FLAG");
      else if(debugBar && HighSignalAlreadySent)
         Print("DBG_FALSE_HIGH_SKIP_SIDE_BUSY");
      else if(debugBar)
         Print("DBG_FALSE_HIGH_SKIP_FORMULA_FALSE highByBar2=", highByBar2, " highByBar1=", highByBar1);
   }
   if(falseHighEnter)
   {
      int foundTail = 1;
      if(highByBar2)
         foundTail = 2;
      string highArrowName = DBG_PREFIX + "FBH_" + IntegerToString((long)barTime);
      double highArrowPrice = chartHigh + 3.0 * _Point;
      if(debugBar)
         Print("DBG_FALSE_HIGH_FOUND tail=", foundTail, " barTime=", DbgTime(barTime), " price=", DbgPrice(highArrowPrice), " name=", highArrowName);
      if(EnableFalseBreakoutSignals)
      {
         PlaceFalseBreakArrowDbg(highArrowName, barTime, highArrowPrice, 222, ANCHOR_BOTTOM, clrRed);
         paint = true;
      }
      PendingHighBar = barTime;
      PendingHighTail = 1;
      PendingHighRangeCandleTime = rangeCandleTime;
      PendingHighRangeHigh = rangeHigh;
      if(highByBar2)
         PendingHighTail = 2;
      if(debugBar)
         Print("DBG_PENDING_HIGH_SET PendingHighBar=", DbgTime(PendingHighBar), " PendingHighTail=", PendingHighTail, " PendingHighRangeCandleTime=", DbgTime(PendingHighRangeCandleTime), " PendingHighRangeHigh=", DbgPrice(PendingHighRangeHigh));
      if(notify && paint)
         ChartRedraw(0);
      PrintDebugExit("FALSE_HIGH_FOUND", barTime);
      return;
   }
   bool lowByBar2 = (min2 <= rangeLow && chartClose > rangeLow);
   bool lowByBar1 = (min2 > rangeLow && chartLow <= rangeLow && chartClose > rangeLow);
   if(!skipLow && !LowSignalAlreadySent && (lowByBar2 || lowByBar1))
   {
      if(EnableFalseBreakoutSignals)
      {
         PlaceFalseBreakArrowDbg(DBG_PREFIX + "FBL_" + IntegerToString((long)barTime), barTime, chartLow - 3.0 * _Point, 221, ANCHOR_TOP, clrGreen);
         paint = true;
      }
      PendingLowBar = barTime;
      PendingLowTail = 1;
      PendingLowRangeCandleTime = rangeCandleTime;
      PendingLowRangeLow = rangeLow;
      if(lowByBar2)
         PendingLowTail = 2;
      if(notify && paint)
         ChartRedraw(0);
      PrintDebugExit("FALSE_LOW_FOUND", barTime);
      return;
   }
   if(notify && paint)
      ChartRedraw(0);
   PrintDebugExit("NORMAL_END", barTime);
}
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
   Print("DBG_SCAN_BEGIN available=", available, " oldest=", oldest);
   int processed = 0;
   datetime oldestProcessed = 0;
   datetime newestProcessed = 0;
   if(oldest >= 1)
   {
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
         if(processed == 0)
            oldestProcessed = barTime;
         newestProcessed = barTime;
         processed++;
         ApplyClosedBar(shift, barTime, rangeCandleTime, rangeHigh, rangeLow, false);
      }
   }
   ChartRedraw(0);
   Print("DBG_SCAN_END available=", available, " oldest=", oldest, " processed=", processed, " oldestProcessed=", DbgTime(oldestProcessed), " newestProcessed=", DbgTime(newestProcessed));
}
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
int OnInit()
{
   DBG_PREFIX = "H1EA_DBG_V10_";
   Print("H1EA DEBUG v1.18 BUILD 20261030-1824 symbol=", _Symbol, " period=", GetTimeframeName((ENUM_TIMEFRAMES)_Period), " CandleTimeframe=", GetTimeframeName(CandleTimeframe), " digits=", _Digits, " point=", DoubleToString(_Point, _Digits));
   if(_Period != PERIOD_M1 || CandleTimeframe != PERIOD_M30)
      Print("DBG_CONFIG_ERROR expectedPeriod=M1 actualPeriod=", GetTimeframeName((ENUM_TIMEFRAMES)_Period), " expectedCandleTimeframe=M30 actualCandleTimeframe=", GetTimeframeName(CandleTimeframe));
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
   bool timerStarted = EventSetTimer(1);
   int timerError = GetLastError();
   if(!timerStarted)
   {
      Print("Ошибка запуска таймера: ", timerError);
      return INIT_FAILED;
   }
   Print("H1EA_dbg v1.0 запущен. Диапазон, сигнал закрытия и перестроение линий: ", GetTimeframeName(CandleTimeframe), "; пробития, ложное пробитие двух свечей и поглощение по закрытию графика: ", GetTimeframeName((ENUM_TIMEFRAMES)_Period));
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, DBG_PREFIX) == 0)
      {
         datetime objectBarTime = 0;
         string highPrefix = DBG_PREFIX + "FBH_";
         if(StringFind(name, highPrefix) == 0)
            objectBarTime = (datetime)StringToInteger(StringSubstr(name, StringLen(highPrefix)));
         ResetLastError();
         bool deleted = ObjectDelete(0, name);
         int deleteError = GetLastError();
         if(IsDebugBar(objectBarTime))
            Print("DBG_ARROW_DELETE reason=DEINIT name=", name, " exists=true result=", deleted, " error=", deleteError);
      }
   }
   ChartRedraw(0);
}
void OnTick()
{
   CheckForNewRangeCandle();
   CheckForNewChartCandle();
   UpdateCountdown();
}
void OnTimer()
{
   UpdateCountdown();
   CheckForNewRangeCandle();
   CheckForNewChartCandle();
}
