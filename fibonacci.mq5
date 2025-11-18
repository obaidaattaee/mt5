//+------------------------------------------------------------------+
//|              1. PROFITUNITY (TRADING CHAOS BY BILL WILLIAMS).mq5 |
//|      Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader. |
//|                                     https://forexalgo-trader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader"
#property link      "https://forexalgo-trader.com"
#property description "1. PROFITUNITY (TRADING CHAOS BY BILL WILLIAMS)"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade obj_Trade;

int handle_Fractals = INVALID_HANDLE; //--- Initialize fractals indicator handle with an invalid handle value
int handle_Alligator = INVALID_HANDLE; //--- Initialize alligator indicator handle with an invalid handle value
int handle_AO = INVALID_HANDLE; //--- Initialize Awesome Oscillator (AO) handle with an invalid handle value
int handle_AC = INVALID_HANDLE; //--- Initialize Accelerator Oscillator (AC) handle with an invalid handle value

double fractals_up[]; //--- Array to store values for upward fractals
double fractals_down[]; //--- Array to store values for downward fractals

double alligator_jaws[]; //--- Array to store values for Alligator's Jaw line
double alligator_teeth[]; //--- Array to store values for Alligator's Teeth line
double alligator_lips[]; //--- Array to store values for Alligator's Lips line

double ao_values[]; //--- Array to store values of the Awesome Oscillator (AO)

double ac_color[]; //--- Array to store color status of the Accelerator Oscillator (AC)
#define AC_COLOR_UP 0 //--- Define constant for upward AC color state
#define AC_COLOR_DOWN 1 //--- Define constant for downward AC color state

double lastFractal_value = 0.0; //--- Variable to store the value of the last detected fractal
enum fractal_direction {FRACTAL_UP, FRACTAL_DOWN, FRACTAL_NEUTRAL}; //--- Enum for fractal direction states
fractal_direction lastFractal_direction = FRACTAL_NEUTRAL; //--- Variable to store the direction of the last fractal

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   //---
   
   handle_Fractals = iFractals(_Symbol,_Period); //--- Initialize the fractals indicator handle
   if (handle_Fractals == INVALID_HANDLE){ //--- Check if the fractals indicator failed to initialize
      Print("ERROR: UNABLE TO INITIALIZE THE FRACTALS INDICATOR. REVERTING NOW!"); //--- Print error if fractals initialization failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   handle_Alligator = iAlligator(_Symbol,_Period,13,8,8,5,5,3,MODE_SMMA,PRICE_MEDIAN); //--- Initialize the alligator indicator with specific settings
   if (handle_Alligator == INVALID_HANDLE){ //--- Check if the alligator indicator failed to initialize
      Print("ERROR: UNABLE TO INITIALIZE THE ALLIGATOR INDICATOR. REVERTING NOW!"); //--- Print error if alligator initialization failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   handle_AO = iAO(_Symbol,_Period); //--- Initialize the Awesome Oscillator (AO) indicator handle
   if (handle_AO == INVALID_HANDLE){ //--- Check if AO indicator failed to initialize
      Print("ERROR: UNABLE TO INITIALIZE THE AO INDICATOR. REVERTING NOW!"); //--- Print error if AO initialization failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   handle_AC = iAC(_Symbol,_Period); //--- Initialize the Accelerator Oscillator (AC) indicator handle
   if (handle_AC == INVALID_HANDLE){ //--- Check if AC indicator failed to initialize
      Print("ERROR: UNABLE TO INITIALIZE THE AC INDICATOR. REVERTING NOW!"); //--- Print error if AC initialization failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   
   if (!ChartIndicatorAdd(0,0,handle_Fractals)){ //--- Add the fractals indicator to the main chart window and check for success
      Print("ERROR: UNABLE TO ADD THE FRACTALS INDICATOR TO CHART. REVERTING NOW!"); //--- Print error if fractals addition failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   if (!ChartIndicatorAdd(0,0,handle_Alligator)){ //--- Add the alligator indicator to the main chart window and check for success
      Print("ERROR: UNABLE TO ADD THE ALLIGATOR INDICATOR TO CHART. REVERTING NOW!"); //--- Print error if alligator addition failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   if (!ChartIndicatorAdd(0,1,handle_AO)){ //--- Add the AO indicator to a separate subwindow and check for success
      Print("ERROR: UNABLE TO ADD THE AO INDICATOR TO CHART. REVERTING NOW!"); //--- Print error if AO addition failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   if (!ChartIndicatorAdd(0,2,handle_AC)){ //--- Add the AC indicator to a separate subwindow and check for success
      Print("ERROR: UNABLE TO ADD THE AC INDICATOR TO CHART. REVERTING NOW!"); //--- Print error if AC addition failed
      return (INIT_FAILED); //--- Exit initialization with failed status
   }
   
   Print("HANDLE ID FRACTALS = ",handle_Fractals); //--- Print the handle ID for fractals
   Print("HANDLE ID ALLIGATOR = ",handle_Alligator); //--- Print the handle ID for alligator
   Print("HANDLE ID AO = ",handle_AO); //--- Print the handle ID for AO
   Print("HANDLE ID AC = ",handle_AC); //--- Print the handle ID for AC

   ArraySetAsSeries(fractals_up,true); //--- Set the fractals_up array as a time series
   ArraySetAsSeries(fractals_down,true); //--- Set the fractals_down array as a time series
   
   ArraySetAsSeries(alligator_jaws,true); //--- Set the alligator_jaws array as a time series
   ArraySetAsSeries(alligator_teeth,true); //--- Set the alligator_teeth array as a time series
   ArraySetAsSeries(alligator_lips,true); //--- Set the alligator_lips array as a time series
   
   ArraySetAsSeries(ao_values,true); //--- Set the ao_values array as a time series
   
   ArraySetAsSeries(ac_color,true); //--- Set the ac_color array as a time series
   
   //---
   return(INIT_SUCCEEDED); //--- Return successful initialization status
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
//---
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
//---

   if (CopyBuffer(handle_Fractals,0,2,3,fractals_up) < 3){ //--- Copy upward fractals data; check if copying is successful
      Print("ERROR: UNABLE TO COPY THE FRACTALS UP DATA. REVERTING!"); //--- Print error message if failed
      return;
   }
   if (CopyBuffer(handle_Fractals,1,2,3,fractals_down) < 3){ //--- Copy downward fractals data; check if copying is successful
      Print("ERROR: UNABLE TO COPY THE FRACTALS DOWN DATA. REVERTING!"); //--- Print error message if failed
      return;
   }

   if (CopyBuffer(handle_Alligator,0,0,3,alligator_jaws) < 3){ //--- Copy Alligator's Jaw data
      Print("ERROR: UNABLE TO COPY THE ALLIGATOR JAWS DATA. REVERTING!");
      return;
   }
   if (CopyBuffer(handle_Alligator,1,0,3,alligator_teeth) < 3){ //--- Copy Alligator's Teeth data
      Print("ERROR: UNABLE TO COPY THE ALLIGATOR TEETH DATA. REVERTING!");
      return;
   }
   if (CopyBuffer(handle_Alligator,2,0,3,alligator_lips) < 3){ //--- Copy Alligator's Lips data
      Print("ERROR: UNABLE TO COPY THE ALLIGATOR LIPS DATA. REVERTING!");
      return;
   }

   if (CopyBuffer(handle_AO,0,0,3,ao_values) < 3){ //--- Copy AO data
      Print("ERROR: UNABLE TO COPY THE AO DATA. REVERTING!");
      return;
   }

   if (CopyBuffer(handle_AC,1,0,3,ac_color) < 3){ //--- Copy AC color data
      Print("ERROR: UNABLE TO COPY THE AC COLOR DATA. REVERTING!");
      return;
   }

   if (isNewBar()){ //--- Check if a new bar has formed
      const int index_fractal = 0;
      if (fractals_up[index_fractal] != EMPTY_VALUE){ //--- Detect upward fractal presence
         lastFractal_value = fractals_up[index_fractal]; //--- Store fractal value
         lastFractal_direction = FRACTAL_UP; //--- Set last fractal direction as up
      }
      if (fractals_down[index_fractal] != EMPTY_VALUE){ //--- Detect downward fractal presence
         lastFractal_value = fractals_down[index_fractal];
         lastFractal_direction = FRACTAL_DOWN;
      }

      if (lastFractal_value != 0.0 && lastFractal_direction != FRACTAL_NEUTRAL){ //--- Ensure fractal is valid
         Print("FRACTAL VALUE = ",lastFractal_value);
         Print("FRACTAL DIRECTION = ",getLastFractalDirection());
      }

      
      Print("ALLIGATOR JAWS = ",NormalizeDouble(alligator_jaws[1],_Digits));
      Print("ALLIGATOR TEETH = ",NormalizeDouble(alligator_teeth[1],_Digits));
      Print("ALLIGATOR LIPS = ",NormalizeDouble(alligator_lips[1],_Digits));
      
      Print("AO VALUE = ",NormalizeDouble(ao_values[1],_Digits+1));
      
      if (ac_color[1] == AC_COLOR_UP){
         Print("AC COLOR UP GREEN = ",AC_COLOR_UP);
      }
      else if (ac_color[1] == AC_COLOR_DOWN){
         Print("AC COLOR DOWN RED = ",AC_COLOR_DOWN);
      }
      

      bool isBreakdown_jaws_buy = alligator_jaws[1] < getClosePrice(1) //--- Check if breakdown for buy
                                  && alligator_jaws[2] > getClosePrice(2);
      bool isBreakdown_jaws_sell = alligator_jaws[1] > getClosePrice(1) //--- Check if breakdown for sell
                                  && alligator_jaws[2] < getClosePrice(2);

      if (lastFractal_direction == FRACTAL_DOWN //--- Conditions for Buy signal
         && isBreakdown_jaws_buy
         && ac_color[1] == AC_COLOR_UP
         && (ao_values[1] > 0 && ao_values[2] < 0)){
         Print("BUY SIGNAL GENERATED");
         obj_Trade.Buy(0.01,_Symbol,getAsk()); //--- Execute Buy order
      }
      else if (lastFractal_direction == FRACTAL_UP //--- Conditions for Sell signal
         && isBreakdown_jaws_sell
         && ac_color[1] == AC_COLOR_DOWN
         && (ao_values[1] < 0 && ao_values[2] > 0)){
         Print("SELL SIGNAL GENERATED");
         obj_Trade.Sell(0.01,_Symbol,getBid()); //--- Execute Sell order
      }

      if (ao_values[1] < 0 && ao_values[2] > 0){ //--- Condition to close all Buy positions
         if (PositionsTotal() > 0){
            Print("CLOSE ALL BUY POSITIONS");
            for (int i=0; i<PositionsTotal(); i++){
               ulong pos_ticket = PositionGetTicket(i); //--- Get position ticket
               if (pos_ticket > 0 && PositionSelectByTicket(pos_ticket)){ //--- Check if ticket is valid
                  ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                  if (pos_type == POSITION_TYPE_BUY){ //--- Close Buy positions
                     obj_Trade.PositionClose(pos_ticket);
                  }
               }
            }
         }
      }
      else if (ao_values[1] > 0 && ao_values[2] < 0){ //--- Condition to close all Sell positions
         if (PositionsTotal() > 0){
            Print("CLOSE ALL SELL POSITIONS");
            for (int i=0; i<PositionsTotal(); i++){
               ulong pos_ticket = PositionGetTicket(i); //--- Get position ticket
               if (pos_ticket > 0 && PositionSelectByTicket(pos_ticket)){ //--- Check if ticket is valid
                  ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                  if (pos_type == POSITION_TYPE_SELL){ //--- Close Sell positions
                     obj_Trade.PositionClose(pos_ticket);
                  }
               }
            }
         }
      }
   }
   
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|   IS NEW BAR FUNCTION                                            |
//+------------------------------------------------------------------+
bool isNewBar(){ 
   static int prevBars = 0; //--- Store previous bar count
   int currBars = iBars(_Symbol,_Period); //--- Get current bar count for the symbol and period
   if (prevBars == currBars) return (false); //--- If bars haven't changed, return false
   prevBars = currBars; //--- Update previous bar count
   return (true); //--- Return true if new bar is detected
}

//+------------------------------------------------------------------+
//|     FUNCTION TO GET FRACTAL DIRECTION                            |
//+------------------------------------------------------------------+

string getLastFractalDirection(){
   string direction_fractal = "NEUTRAL"; //--- Default direction set to NEUTRAL
   
   if (lastFractal_direction == FRACTAL_UP) return ("UP"); //--- Return UP if last fractal was up
   else if (lastFractal_direction == FRACTAL_DOWN) return ("DOWN"); //--- Return DOWN if last fractal was down
   
   return (direction_fractal); //--- Return NEUTRAL if no specific direction
}

//+------------------------------------------------------------------+
//|        FUNCTION TO GET CLOSE PRICES                              |
//+------------------------------------------------------------------+

double getClosePrice(int bar_index){
   return (iClose(_Symbol, _Period, bar_index)); //--- Retrieve the close price of the specified bar
}

//+------------------------------------------------------------------+
//|        FUNCTION TO GET ASK PRICES                                |
//+------------------------------------------------------------------+

double getAsk(){
   return (NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits)); //--- Get and normalize the Ask price
}

//+------------------------------------------------------------------+
//|        FUNCTION TO GET BID PRICES                                |
//+------------------------------------------------------------------+

double getBid(){
   return (NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits)); //--- Get and normalize the Bid price
}
