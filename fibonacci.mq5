//+------------------------------------------------------------------+
//|                                 Fibonacci Retracement Ratios.mq5 |
//|                           Copyright 2025, Allan Munene Mutiiria. |
//|                                   https://t.me/Forex_Algo_Trader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Allan Munene Mutiiria."
#property link      "https://t.me/Forex_Algo_Trader"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>                                        // For trade execution

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum CloseOnNewEnum {                                             // Define enum for closing on new Fibonacci
   CloseOnNew_No  = 0,                                            // No
   CloseOnNew_Yes = 1                                             // Yes
};
enum TrailingTypeEnum {                                           // Define enum for trailing stop types
   Trailing_None   = 0,                                           // None
   Trailing_Points = 2                                            // By Points
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input bool   UseDailyApproach     = true;                         // Use daily candle (true) or array (false)
input string fibLevelsStr         = "50,61.8";                    // Comma-separated Fib levels for entry (e.g., 50,61.8)
input int    maxTradesPerLevel    = 1;                            // Max trades per level per Fib period (0=unlimited)
input CloseOnNewEnum CloseOnNewFib = CloseOnNew_No;               // Close trades on new Fib calc
input TrailingTypeEnum TrailingType = Trailing_None;              // Trailing Stop Type
input double Trailing_Stop_Pips   = 30.0;                         // Trailing Stop in Pips (for Points type)
input double Min_Profit_To_Trail_Pips = 50.0;                     // Min Profit to Start Trailing in Pips
input int    LookbackSize         = 100;                          // Number of candles for array approach
input double LotSize              = 0.1;                          // Trade lot size
input int    MagicNumber          = 12345;                        // Magic number for trades
input bool   IncludeCurrentBar    = false;                        // Include current bar in array calcs for updates
input double SlBufferPercent      = 0.0;                          // SL buffer percent of range (0=no buffer)
input double TpBufferPercent      = 0.0;                          // TP buffer percent of range (0=no buffer)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade obj_Trade;                                                 //--- Trade object
int    barsTotal;                                                 //--- For daily approach
#define FIB_OBJ "Fibonacci Retracement"                           //--- Define Fibonacci object name
// Persistent variables for both approaches
static double storedEntryLvls[];                                  //--- Array of entry levels
static int    storedTradesCount[];                                //--- Trades count per level
static double storedSl = 0.0;                                     //--- Stored stop loss
static double storedTp = 0.0;                                     //--- Stored take profit
static string storedInfo = "";                                    //--- Stored information string
static bool   storedIsBullish = false;                            //--- Stored bullish flag
static double fibLevels[];                                        //--- Parsed Fibonacci levels (original order)
static string lastShownInfo = "";                                 //--- To detect changes and avoid unnecessary updates
// For array approach
static bool   fibCalculated = false;                              //--- Fibonacci calculated flag
static double currentHigh = 0.0;                                  //--- Current high
static double currentLow = 0.0;                                   //--- Current low
static string fibName = "Fib_Array";                              //--- Fibonacci name for array

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   obj_Trade.SetExpertMagicNumber(MagicNumber);                   //--- Set magic number for trade object
   // Force initial calculation for daily approach
   barsTotal = 0;                                                 //--- Ensure first tick updates
   // Parse `fibLevelsStr` into `fibLevels` array (comma-separated)
   string tempLevels[];                                           //--- Temporary levels array
   int numLevels = StringSplit(fibLevelsStr, ',', tempLevels);    //--- Split string into levels using comma
   ArrayResize(fibLevels, numLevels);                             //--- Resize fibLevels array
   for (int i = 0; i < numLevels; i++) {                          //--- Iterate through levels
      fibLevels[i] = StringToDouble(tempLevels[i]);               //--- Convert to double
   }
   ArrayResize(storedEntryLvls, numLevels);                       //--- Resize storedEntryLvls
   ArrayResize(storedTradesCount, numLevels);                     //--- Resize storedTradesCount
   ArrayInitialize(storedEntryLvls, 0.0);                         //--- Initialize entry levels to 0.0
   ArrayInitialize(storedTradesCount, 0);                         //--- Initialize trade counts to 0
   // Clean up old labels
   ObjectsDeleteAll(0, "InfoLabel_", -1, OBJ_LABEL);              //--- Delete all info labels
   lastShownInfo = "";                                            //--- Reset last shown info
   // Clean up old Fib object for array
   ObjectDelete(0, fibName);                                      //--- Delete Fibonacci object
   fibCalculated = false;                                         //--- Reset calculated flag
   return(INIT_SUCCEEDED);                                        //--- Return success
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "InfoLabel_", -1, OBJ_LABEL);              //--- Delete all info labels
   ObjectDelete(0, FIB_OBJ);                                      //--- Delete daily Fibonacci
   ObjectDelete(0, fibName);                                      //--- Delete array Fibonacci
}

//+------------------------------------------------------------------+
//| Display info using labels without flicker                        |
//+------------------------------------------------------------------+
void ShowLabels(string info) {
   if (info == lastShownInfo) return;                             //--- Skip if no change
   lastShownInfo = info;                                          //--- Update last info
   // Split info into lines
   string lines[];                                                //--- Lines array
   ushort nlSep = StringGetCharacter("\n", 0);                    //--- Get newline sep
   int numLines = StringSplit(info, nlSep, lines);                //--- Split into lines
   int y = 10;                                                    //--- Starting Y
   for (int i = 0; i < numLines; i++) {                           //--- Iterate lines
      string name = "InfoLabel_" + IntegerToString(i);            //--- Label name
      if (ObjectFind(0, name) < 0) {                              //--- Check exists
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);               //--- Create label
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER); //--- Set corner
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);        //--- Set X distance
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);          //--- Set font size
      }
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);            //--- Set Y distance
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);           //--- Set text
      y += 15;                                                    //--- Increment Y
   }
   // Delete extra labels if numLines decreased
   for (int i = numLines; ; i++) {                                //--- Iterate extras
      string name = "InfoLabel_" + IntegerToString(i);            //--- Label name
      if (ObjectFind(0, name) < 0) break;                         //--- Break if none
      ObjectDelete(0, name);                                      //--- Delete label
   }
}

//+------------------------------------------------------------------+
//| Check if price breaches the current Fib extremes                 |
//+------------------------------------------------------------------+
bool IsBreach() {
   if (!fibCalculated) return false;                              //--- Return false if not calculated
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);            //--- Get bid price
   if (storedIsBullish) {                                         //--- Check bullish
      // For bullish, 0% is high, 100% is low
      return (bid > currentHigh || bid < currentLow);             //--- Check breach
   } else {                                                       //--- Handle bearish
      // For bearish, 0% is low, 100% is high
      return (bid > currentLow || bid < currentHigh);             //--- Check breach
   }
}

//+------------------------------------------------------------------+
//| Close all positions with matching magic and symbol               |
//+------------------------------------------------------------------+
void CloseAllPositions() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {              //--- Iterate positions reverse
      if (PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) { //--- Check position
         obj_Trade.PositionClose(PositionGetTicket(i));           //--- Close position
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Points Trailing Stop (from reference)                      |
//+------------------------------------------------------------------+
void ApplyPointsTrailing() {
   double point = _Point;                                         //--- Get point value
   for (int i = PositionsTotal() - 1; i >= 0; i--) {              //--- Iterate positions reverse
      if (PositionGetTicket(i) > 0) {                             //--- Check valid ticket
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) { //--- Check symbol and magic
            double sl = PositionGetDouble(POSITION_SL);           //--- Get SL
            double tp = PositionGetDouble(POSITION_TP);           //--- Get TP
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN); //--- Get open price
            ulong ticket = PositionGetInteger(POSITION_TICKET);   //--- Get ticket
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) { //--- Check buy
               double newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - Trailing_Stop_Pips * point, _Digits); //--- Calc new SL
               if (newSL > sl && SymbolInfoDouble(_Symbol, SYMBOL_BID) - openPrice > Min_Profit_To_Trail_Pips * point) { //--- Check conditions
                  obj_Trade.PositionModify(ticket, newSL, tp);    //--- Modify position
               }
            } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) { //--- Check sell
               double newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + Trailing_Stop_Pips * point, _Digits); //--- Calc new SL
               if (newSL < sl && openPrice - SymbolInfoDouble(_Symbol, SYMBOL_ASK) > Min_Profit_To_Trail_Pips * point) { //--- Check conditions
                  obj_Trade.PositionModify(ticket, newSL, tp);    //--- Modify position
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Points trailing can run anytime
   if (TrailingType == Trailing_Points && PositionsTotal() > 0) { //--- Check trailing
      ApplyPointsTrailing();                                      //--- Apply trailing
   }
   
   if (UseDailyApproach) {                                        //--- Check daily approach
      // Daily approach logic
      int bars = iBars(_Symbol, PERIOD_D1);                       //--- Get daily bars
      if (barsTotal != bars) { //--- Check new bar
         barsTotal = bars;                                        //--- Update bars total
         
         if (CloseOnNewFib == CloseOnNew_Yes) {                   //--- Check close on new
            CloseAllPositions();                                  //--- Close positions
         }
         
         ObjectDelete(0, FIB_OBJ);                                //--- Delete Fib object
         double openPrice = iOpen(_Symbol, PERIOD_D1, 1);         //--- Get open price
         double closePrice = iClose(_Symbol, PERIOD_D1, 1);       //--- Get close price
         double high = iHigh(_Symbol, PERIOD_D1, 1);              //--- Get high
         double low = iLow(_Symbol, PERIOD_D1, 1);                //--- Get low
         datetime startingTime = iTime(_Symbol, PERIOD_D1, 1);    //--- Get start time
         datetime endingTime = iTime(_Symbol, PERIOD_D1, 0) - 1;  //--- Get end time
         double range = high - low;                               //--- Calc range
         storedIsBullish = (closePrice > openPrice);              //--- Set bullish flag
         string levelsList = "";                                  //--- Init levels list
         for (int i = 0; i < ArraySize(fibLevels); i++) {         //--- Iterate levels
            storedTradesCount[i] = 0;                             //--- Reset count
            if (storedIsBullish) {                                //--- Check bullish
               storedEntryLvls[i] = NormalizeDouble(high - range * fibLevels[i] / 100, _Digits); //--- Calc entry
            } else {                                              //--- Handle bearish
               storedEntryLvls[i] = NormalizeDouble(low + range * fibLevels[i] / 100, _Digits); //--- Calc entry
            }
            levelsList += DoubleToString(fibLevels[i], 1) + ": " + DoubleToString(storedEntryLvls[i], _Digits) + "\n"; //--- Add to list
         }
         if (storedIsBullish) {                                   //--- Check bullish
            // Bullish: Fibo from low to high for correct 0% at high, 100% at low, green
            ObjectCreate(0, FIB_OBJ, OBJ_FIBO, 0, startingTime, low, endingTime, high); //--- Create Fib
            ObjectSetInteger(0, FIB_OBJ, OBJPROP_COLOR, clrGreen); //--- Set color
            for (int i = 0; i < ObjectGetInteger(0, FIB_OBJ, OBJPROP_LEVELS); i++) { //--- Iterate levels
               ObjectSetInteger(0, FIB_OBJ, OBJPROP_LEVELCOLOR, i, clrGreen); //--- Set level color
            }
            storedSl = NormalizeDouble(low - range * (SlBufferPercent / 100), _Digits); //--- Calc SL
            storedTp = NormalizeDouble(high + range * (TpBufferPercent / 100), _Digits); //--- Calc TP
            storedInfo = "Daily Approach - Bullish\n" +           //--- Set info
                         "Open: " + DoubleToString(openPrice, _Digits) + "\n" +
                         "Close: " + DoubleToString(closePrice, _Digits) + "\n" +
                         "Buy Entries:\n" + levelsList +
                         "SL: " + DoubleToString(storedSl, _Digits) + "\n" +
                         "TP: " + DoubleToString(storedTp, _Digits);
            Print("New daily bar: Bullish Fibonacci levels calculated. Entries: ", levelsList); //--- Log
         } else {                                                 //--- Handle bearish
            // Bearish: Fibo from high to low for correct 0% at low, 100% at high, red
            ObjectCreate(0, FIB_OBJ, OBJ_FIBO, 0, startingTime, high, endingTime, low); //--- Create Fib
            ObjectSetInteger(0, FIB_OBJ, OBJPROP_COLOR, clrRed);  //--- Set color
            for (int i = 0; i < ObjectGetInteger(0, FIB_OBJ, OBJPROP_LEVELS); i++) { //--- Iterate levels
               ObjectSetInteger(0, FIB_OBJ, OBJPROP_LEVELCOLOR, i, clrRed); //--- Set level color
            }
            storedSl = NormalizeDouble(high + range * (SlBufferPercent / 100), _Digits); //--- Calc SL
            storedTp = NormalizeDouble(low - range * (TpBufferPercent / 100), _Digits); //--- Calc TP
            storedInfo = "Daily Approach - Bearish\n" +           //--- Set info
                         "Open: " + DoubleToString(openPrice, _Digits) + "\n" +
                         "Close: " + DoubleToString(closePrice, _Digits) + "\n" +
                         "Sell Entries:\n" + levelsList +
                         "SL: " + DoubleToString(storedSl, _Digits) + "\n" +
                         "TP: " + DoubleToString(storedTp, _Digits);
            Print("New daily bar: Bearish Fibonacci levels calculated. Entries: ", levelsList); //--- Log
         }
      }
   } else {                                                       //--- Array approach
      // Array approach: Calculate only when not calculated or breached
      if (!fibCalculated || IsBreach()) {                         //--- Check recalc
         if (fibCalculated) {                                     //--- Check calculated
            if (CloseOnNewFib == CloseOnNew_Yes) {                //--- Check close on new
               CloseAllPositions();                               //--- Close positions
            }
            // Invalidate and forget previous
            ObjectDelete(0, fibName);                             //--- Delete Fib
            fibCalculated = false;                                //--- Reset flag
         }
         int startShift = IncludeCurrentBar ? 0 : 1;              //--- Set start shift
         int copyCount = IncludeCurrentBar ? LookbackSize : LookbackSize; //--- Set copy count
         double high[], low[];                                    //--- High and low arrays
         ArraySetAsSeries(high, true);                            //--- Set as series
         ArraySetAsSeries(low, true);                             //--- Set as series
         if (CopyHigh(_Symbol, _Period, startShift, copyCount, high) <= 0) return; //--- Copy high
         if (CopyLow(_Symbol, _Period, startShift, copyCount, low) <= 0) return; //--- Copy low
         int highestCandle = ArrayMaximum(high, 0, copyCount);    //--- Get highest
         int lowestCandle = ArrayMinimum(low, 0, copyCount);      //--- Get lowest
         MqlRates pArray[];                                       //--- Rates array
         ArraySetAsSeries(pArray, true);                          //--- Set as series
         int pData = CopyRates(_Symbol, _Period, startShift, copyCount, pArray); //--- Copy rates
         if (pData <= 0) return;                                  //--- Check data
         double highVal = pArray[highestCandle].high;             //--- Get high val
         double lowVal = pArray[lowestCandle].low;                //--- Get low val
         double range = highVal - lowVal;                         //--- Calc range
         int oldestShift = IncludeCurrentBar ? (LookbackSize - 1) : LookbackSize; //--- Oldest shift
         double openCandle = iOpen(_Symbol, _Period, oldestShift); //--- Get open
         double closeCandle = iClose(_Symbol, _Period, IncludeCurrentBar ? 0 : 1); //--- Get close
         storedIsBullish = (closeCandle > openCandle);            //--- Set bullish
         string levelsList = "";                                  //--- Init list
         for (int i = 0; i < ArraySize(fibLevels); i++) {         //--- Iterate levels
            storedTradesCount[i] = 0;                             //--- Reset count
            if (storedIsBullish) {                                //--- Check bullish
               storedEntryLvls[i] = NormalizeDouble(highVal - range * fibLevels[i] / 100, _Digits); //--- Calc entry
            } else {                                              //--- Handle bearish
               storedEntryLvls[i] = NormalizeDouble(lowVal + range * fibLevels[i] / 100, _Digits); //--- Calc entry
            }
            levelsList += DoubleToString(fibLevels[i], 1) + ": " + DoubleToString(storedEntryLvls[i], _Digits) + "\n"; //--- Add to list
         }
         if (storedIsBullish) {                                   //--- Check bullish
            // Bullish: Anchor from low to high
            datetime time1 = pArray[lowestCandle].time;           //--- Time1
            double price1 = lowVal;                               //--- Price1
            datetime time2 = pArray[highestCandle].time;          //--- Time2
            double price2 = highVal;                              //--- Price2
            ObjectCreate(0, fibName, OBJ_FIBO, 0, time1, price1, time2, price2); //--- Create Fib
            ObjectSetInteger(0, fibName, OBJPROP_COLOR, clrGreen); //--- Set color
            for (int i = 0; i < ObjectGetInteger(0, fibName, OBJPROP_LEVELS); i++) { //--- Iterate levels
               ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, i, clrGreen); //--- Set level color
            }
            storedSl = NormalizeDouble(lowVal - range * (SlBufferPercent / 100), _Digits); //--- Calc SL
            storedTp = NormalizeDouble(highVal + range * (TpBufferPercent / 100), _Digits); //--- Calc TP
            storedInfo = "Array Approach - Bullish\n" +           //--- Set info
                         "Array Open: " + DoubleToString(openCandle, _Digits) + "\n" +
                         "Array Close: " + DoubleToString(closeCandle, _Digits) + "\n" +
                         "Buy Entries:\n" + levelsList +
                         "SL: " + DoubleToString(storedSl, _Digits) + "\n" +
                         "TP: " + DoubleToString(storedTp, _Digits);
         } else {                                                 //--- Handle bearish
            // Bearish: Anchor from high to low
            datetime time1 = pArray[highestCandle].time;          //--- Time1
            double price1 = highVal;                              //--- Price1
            datetime time2 = pArray[lowestCandle].time;           //--- Time2
            double price2 = lowVal;                               //--- Price2
            ObjectCreate(0, fibName, OBJ_FIBO, 0, time1, price1, time2, price2); //--- Create Fib
            ObjectSetInteger(0, fibName, OBJPROP_COLOR, clrRed);  //--- Set color
            for (int i = 0; i < ObjectGetInteger(0, fibName, OBJPROP_LEVELS); i++) { //--- Iterate levels
               ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, i, clrRed); //--- Set level color
            }
            storedSl = NormalizeDouble(highVal + range * (SlBufferPercent / 100), _Digits); //--- Calc SL
            storedTp = NormalizeDouble(lowVal - range * (TpBufferPercent / 100), _Digits); //--- Calc TP
            storedInfo = "Array Approach - Bearish\n" +           //--- Set info
                         "Array Open: " + DoubleToString(openCandle, _Digits) + "\n" +
                         "Array Close: " + DoubleToString(closeCandle, _Digits) + "\n" +
                         "Sell Entries:\n" + levelsList +
                         "SL: " + DoubleToString(storedSl, _Digits) + "\n" +
                         "TP: " + DoubleToString(storedTp, _Digits);
         }
         currentHigh = storedIsBullish ? highVal : lowVal;        //--- Set current high
         currentLow = storedIsBullish ? lowVal : highVal;         //--- Set current low
         fibCalculated = true;                                    //--- Set calculated
      }
   }
   
   // Display info using labels (but only update if changed)
   ShowLabels(storedInfo);                                        //--- Show labels
   
   // Entry logic: Checked every tick using stored levels (no existing position)
   if (PositionsTotal() == 0) {                                   //--- Check no positions
      double close1 = iClose(_Symbol, _Period, 1);                //--- Get close 1
      double close2 = iClose(_Symbol, _Period, 2);                //--- Get close 2
      for (int i = 0; i < ArraySize(storedEntryLvls); i++) {      //--- Iterate levels
         // Only enter on levels 0 < fib <=100 (retracements), ignore 0/100/extensions for entry
         if (fibLevels[i] <= 0 || fibLevels[i] > 100.0) continue; //--- Skip invalid
         if ((maxTradesPerLevel == 0 || storedTradesCount[i] < maxTradesPerLevel) && //--- Check count
             ((storedIsBullish && close1 > storedEntryLvls[i] && close2 <= storedEntryLvls[i]) || //--- Buy cross
              (!storedIsBullish && close1 < storedEntryLvls[i] && close2 >= storedEntryLvls[i]))) { //--- Sell cross
            string levelStr = DoubleToString(fibLevels[i], 1);     //--- Level string
            ulong ticket = 0;                                      //--- Init ticket
            if (storedIsBullish) {                                 //--- Check buy
               Print("Buy signal triggered at ", close1, " crossing level ", levelStr, " (", storedEntryLvls[i], ")"); //--- Log
               obj_Trade.Buy(LotSize, _Symbol, 0, storedSl, storedTp, "Fibo Buy at " + levelStr); //--- Open buy
               ticket = obj_Trade.ResultDeal();                   //--- Get deal
            } else {                                               //--- Handle sell
               Print("Sell signal triggered at ", close1, " crossing level ", levelStr, " (", storedEntryLvls[i], ")"); //--- Log
               obj_Trade.Sell(LotSize, _Symbol, 0, storedSl, storedTp, "Fibo Sell at " + levelStr); //--- Open sell
               ticket = obj_Trade.ResultDeal();                   //--- Get deal
            }
            storedTradesCount[i]++;                                //--- Increment count
            break;                                                 //--- Break loop
         }
      }
   }
   
   // Redraw chart objects
   ChartRedraw();                                                 //--- Redraw chart
}
//+------------------------------------------------------------------+
