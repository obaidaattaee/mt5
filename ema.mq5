//+------------------------------------------------------------------+
//|                                       1. Strategy Tracker EA.mq5 |
//|                           Copyright 2025, Allan Munene Mutiiria. |
//|                                   https://t.me/Forex_Algo_Trader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Allan Munene Mutiiria."
#property link      "https://t.me/Forex_Algo_Trader"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum TradeMode {                                                  // Define trade mode enum
   Visual_Only,                                                   // Visual Only
   Open_Trades                                                    // Open Trades
};

enum TPLevel {                                                    // Define TP level enum
   Level_1,                                                       // TP1
   Level_2,                                                       // TP2
   Level_3                                                        // TP3
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input TradeMode        trade_mode      = Visual_Only;             // Trading Mode
input int              fast_ma_period  = 10;                      // Fast MA Period
input int              slow_ma_period  = 20;                      // Slow MA Period
input int              filter_ma_period = 200;                    // Filter MA Period
input ENUM_MA_METHOD   ma_method       = MODE_SMA;                // MA Method
input ENUM_APPLIED_PRICE ma_price      = PRICE_CLOSE;             // MA Applied Price
input int              tp1_points      = 50;                      // TP1 Points
input int              tp2_points      = 100;                     // TP2 Points
input int              tp3_points      = 150;                     // TP3 Points
input TPLevel          tp_level        = Level_1;                 // Select TP Level
input int              sl_points       = 150;                     // SL Points
input int              dash_x          = 30;                      // Dashboard X Offset
input int              dash_y          = 30;                      // Dashboard Y Offset

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
// Handles for indicators
int h_fast_ma, h_slow_ma, h_filter_ma;                            //--- MA handles
// Active signal structure
struct ActiveSignal {                                             // Define active signal structure
   bool     active;                                               //--- Signal active flag
   int      pos_type;                                             //--- Position type (1 buy, -1 sell)
   datetime entry_time;                                           //--- Entry time
   double   entry_price;                                          //--- Entry price
   double   tp1, tp2, tp3, sl;                                    //--- TP and SL levels
   bool     hit_tp1, hit_tp2, hit_tp3;                            //--- TP hit flags
   bool     hit_sl;                                               //--- SL hit flag
   datetime close_time;                                           //--- Close time
};
ActiveSignal current_signal;                                      //--- Current signal instance
// Stats
long   total_signals      = 0;                                    //--- Total signals count
long   wins               = 0;                                    //--- Wins count
long   losses             = 0;                                    //--- Losses count
double total_profit_points = 0.0;                                 //--- Total profit in points
// Dashboard prefix
string dash_prefix = "ProDashboard_";                             //--- Dashboard object prefix
// Last bar time
datetime last_bar_time = 0;                                       //--- Last processed bar time
// Position ticket for Open_Trades mode
ulong position_ticket = -1;                                       //--- Position ticket

//+------------------------------------------------------------------+
//| Function to create rectangle label                               |
//+------------------------------------------------------------------+
bool createRecLabel(string objName, int xD, int yD, int xS, int yS,
                    color clrBg, int widthBorder, color clrBorder = clrNONE,
                    ENUM_BORDER_TYPE borderType = BORDER_FLAT,
                    ENUM_LINE_STYLE borderStyle = STYLE_SOLID,
                    ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER) {
   ResetLastError();                                              //--- Reset last error
   if (!ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) { //--- Create rectangle label
      Print(__FUNCTION__, ": failed to create rec label! Error code = ", _LastError); //--- Log error
      return (false);                                             //--- Return failure
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xD);           //--- Set X distance
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yD);           //--- Set Y distance
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xS);               //--- Set X size
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, yS);               //--- Set Y size
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);          //--- Set corner
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrBg);          //--- Set background color
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, borderType); //--- Set border type
   ObjectSetInteger(0, objName, OBJPROP_STYLE, borderStyle);      //--- Set border style
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, widthBorder);      //--- Set border width
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBorder);        //--- Set border color
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);             //--- Set to foreground
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);            //--- Disable state
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);       //--- Disable selectable
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);         //--- Disable selected
   ChartRedraw(0);                                                //--- Redraw chart
   return (true);                                                 //--- Return success
}

//+------------------------------------------------------------------+
//| Function to create text label                                    |
//+------------------------------------------------------------------+
bool createLabel(string objName, int xD, int yD,
                 string txt, color clrTxt = clrBlack, int fontSize = 12,
                 string font = "Arial Rounded MT Bold",
                 ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER) {
   ResetLastError();                                              //--- Reset last error
   if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {          //--- Create label
      Print(__FUNCTION__, ": failed to create the label! Error code = ", _LastError); //--- Log error
      return (false);                                             //--- Return failure
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xD);           //--- Set X distance
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yD);           //--- Set Y distance
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);          //--- Set corner
   ObjectSetString(0, objName, OBJPROP_TEXT, txt);                //--- Set text
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTxt);           //--- Set color
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);      //--- Set font size
   ObjectSetString(0, objName, OBJPROP_FONT, font);               //--- Set font
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);             //--- Set to foreground
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);            //--- Disable state
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);       //--- Disable selectable
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);         //--- Disable selected
   ChartRedraw(0);                                                //--- Redraw chart
   return (true);                                                 //--- Return success
}

//+------------------------------------------------------------------+
//| Function to create trend line                                    |
//+------------------------------------------------------------------+
bool createTrendline(string objName, datetime time1, double price1, datetime time2, double price2, color clr, ENUM_LINE_STYLE line_style = STYLE_SOLID, bool isBack = false, bool ray_right = false) {
   ResetLastError();                                              //--- Reset last error
   if (!ObjectCreate(0, objName, OBJ_TREND, 0, time1, price1, time2, price2)) { //--- Create trendline
      Print(__FUNCTION__, ": Failed to create trendline: Error Code: ", GetLastError()); //--- Log error
      return (false);                                             //--- Return failure
   }
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);              //--- Set color
   ObjectSetInteger(0, objName, OBJPROP_STYLE, line_style);       //--- Set style
   ObjectSetInteger(0, objName, OBJPROP_BACK, isBack);            //--- Set back
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, ray_right);    //--- Set ray right
   ChartRedraw(0);                                                //--- Redraw chart
   return (true);                                                 //--- Return success
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   h_fast_ma = iMA(_Symbol, PERIOD_CURRENT, fast_ma_period, 0, ma_method, ma_price); //--- Create fast MA
   h_slow_ma = iMA(_Symbol, PERIOD_CURRENT, slow_ma_period, 0, ma_method, ma_price); //--- Create slow MA
   h_filter_ma = iMA(_Symbol, PERIOD_CURRENT, filter_ma_period, 0, ma_method, ma_price); //--- Create filter MA
   if (h_fast_ma == INVALID_HANDLE || h_slow_ma == INVALID_HANDLE || h_filter_ma == INVALID_HANDLE) { //--- Check handles
      Print("Failed to initialize MA handles");                   //--- Log error
      return(INIT_FAILED);                                        //--- Return failure
   }
   current_signal.active = false;                                 //--- Reset active
   current_signal.hit_sl = false;                                 //--- Reset SL hit
   current_signal.close_time = 0;                                 //--- Reset close time
   CreateDashboard();                                             //--- Create dashboard
   return(INIT_SUCCEEDED);                                        //--- Return success
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, dash_prefix);                              //--- Delete dashboard objects
   ObjectsDeleteAll(0, "Signal_");                                //--- Delete signal objects
   ObjectsDeleteAll(0, "Initial_");                               //--- Delete initial objects
   IndicatorRelease(h_fast_ma);                                   //--- Release fast MA
   IndicatorRelease(h_slow_ma);                                   //--- Release slow MA
   IndicatorRelease(h_filter_ma);                                 //--- Release filter MA
   if (trade_mode == Open_Trades && position_ticket != -1) {      //--- Check open trades mode
      MqlTick tick;                                               //--- Tick structure
      if (SymbolInfoTick(_Symbol, tick)) {                        //--- Get tick
         double close_price = (current_signal.pos_type == 1) ? tick.bid : tick.ask; //--- Get close price
         MqlTradeRequest close_request = {};                      //--- Close request
         MqlTradeResult close_result = {};                        //--- Close result
         close_request.action = TRADE_ACTION_DEAL;                //--- Set action
         close_request.symbol = _Symbol;                          //--- Set symbol
         close_request.volume = 0.1;                              //--- Set volume
         close_request.type = (current_signal.pos_type == 1) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; //--- Set type
         close_request.price = close_price;                       //--- Set price
         close_request.deviation = 3;                             //--- Set deviation
         close_request.position = position_ticket;                 //--- Set position
         if (!OrderSend(close_request, close_result)) {           //--- Send close
            Print("Failed to close trade on deinit: ", GetLastError()); //--- Log error
         }
         position_ticket = -1;                                    //--- Reset ticket
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   MqlTick tick;                                                  //--- Tick structure
   if (!SymbolInfoTick(_Symbol, tick)) return;                    //--- Get tick or return
   double bid = tick.bid;                                         //--- Get bid
   double ask = tick.ask;                                         //--- Get ask
   MqlRates rates[2];                                             //--- Rates array
   if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) return; //--- Copy rates or return
   bool new_bar = (rates[0].time > last_bar_time);                //--- Check new bar
   if (new_bar) last_bar_time = rates[0].time;                    //--- Update last time
   double fast_buf[], slow_buf[], filter_buf[];                //--- Buffers
   ArraySetAsSeries(fast_buf, true);
   ArraySetAsSeries(slow_buf, true);
   ArraySetAsSeries(filter_buf, true);
   if (CopyBuffer(h_fast_ma, 0, 0, 3, fast_buf) < 3) return;      //--- Copy fast or return
   if (CopyBuffer(h_slow_ma, 0, 0, 3, slow_buf) < 3) return;      //--- Copy slow or return
   if (CopyBuffer(h_filter_ma, 0, 0, 2, filter_buf) < 2) return;  //--- Copy filter or return
   double fast_1 = fast_buf[1];                                   //--- Fast MA 1
   double fast_2 = fast_buf[2];                                   //--- Fast MA 2
   double slow_1 = slow_buf[1];                                   //--- Slow MA 1
   double slow_2 = slow_buf[2];                                   //--- Slow MA 2
   double filter_1 = filter_buf[1];                               //--- Filter MA 1
   double close_1 = rates[1].close;                               //--- Close 1
   int signal_type = 0;                                           //--- Init signal type
   if (new_bar) {                                                 //--- Check new bar
      if (fast_2 <= slow_2 && fast_1 > slow_1 && close_1 > filter_1) signal_type = 1; //--- Buy signal
      else if (fast_2 >= slow_2 && fast_1 < slow_1 && close_1 < filter_1) signal_type = -1; //--- Sell signal
   }
   if (signal_type != 0) {                                        //--- Check signal
      if (current_signal.active && current_signal.pos_type != signal_type) { //--- Check active opposite
         double close_price = (current_signal.pos_type == 1) ? bid : ask; //--- Get close price
         CloseVirtualPosition(close_price, true);                  //--- Close early
      }
      if (!current_signal.active) {                                //--- Check not active
         double entry_price = (signal_type == 1) ? ask : bid;      //--- Get entry price
         OpenVirtualPosition(signal_type, rates[1].time, entry_price); //--- Open virtual
         string name = "Signal_Entry_" + TimeToString(rates[1].time); //--- Entry name
         ObjectCreate(0, name, OBJ_ARROW, 0, rates[1].time, signal_type == 1 ? rates[1].low : rates[1].high); //--- Create arrow
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (signal_type == 1 ? 236 : 238)); //--- Set code
         ObjectSetString(0, name, OBJPROP_FONT, "Wingdings");      //--- Set font
         ObjectSetInteger(0, name, OBJPROP_COLOR, signal_type == 1 ? clrGreen : clrRed); //--- Set color
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);          //--- Set size
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, signal_type == 1 ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER); //--- Set anchor
         if (trade_mode == Open_Trades) {                          //--- Check open trades
            MqlTradeRequest request = {};                          //--- Request
            MqlTradeResult result = {};                            //--- Result
            request.action = TRADE_ACTION_DEAL;                    //--- Set action
            request.symbol = _Symbol;                              //--- Set symbol
            request.volume = 0.1;                                  //--- Set volume
            request.type = signal_type == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; //--- Set type
            request.price = signal_type == 1 ? ask : bid;          //--- Set price
            request.deviation = 3;                                 //--- Set deviation
            double selected_tp = 0;                                //--- Init TP
            switch(tp_level) {                                     //--- Select TP
               case Level_1: selected_tp = current_signal.tp1; break; //--- TP1
               case Level_2: selected_tp = current_signal.tp2; break; //--- TP2
               case Level_3: selected_tp = current_signal.tp3; break; //--- TP3
            }
            request.tp = selected_tp;                              //--- Set TP
            request.sl = current_signal.sl;                        //--- Set SL
            if(!OrderSend(request, result)) {                      //--- Send order
               Print("Failed to open trade: ", GetLastError());    //--- Log error
            } else {                                               //--- Success
               position_ticket = result.deal;                      //--- Set ticket
            }
         }
      }
   }
   if (current_signal.active) {                                   //--- Check active
      // Detect if real position closed automatically (TP/SL)
      if (trade_mode == Open_Trades && position_ticket != -1 && !PositionSelectByTicket(position_ticket)) { //--- Check closed
         double close_price = GetPositionClosePrice(position_ticket); //--- Get close price
         bool hit_sl = MathAbs(close_price - current_signal.sl) < _Point * 5; //--- Check SL hit
         current_signal.hit_sl = hit_sl;                        //--- Set SL hit
         if (hit_sl) DrawSLHit(TimeCurrent(), current_signal.sl); //--- Draw SL
         CloseVirtualPosition(close_price, false);               //--- Close virtual
      } else {                                                  //--- Not auto closed
         // Check for visual hits (TP levels)
         if (!current_signal.hit_tp1) {                          //--- Check TP1
            bool tp1_hit = false;                                //--- Init hit
            if (current_signal.pos_type == 1 && bid >= current_signal.tp1) tp1_hit = true; //--- Buy hit
            if (current_signal.pos_type == -1 && ask <= current_signal.tp1) tp1_hit = true; //--- Sell hit
            if (tp1_hit) {                                       //--- Hit
               current_signal.hit_tp1 = true;                    //--- Set hit
               DrawTPHit(1, TimeCurrent(), current_signal.tp1, tp1_points); //--- Draw hit
            }
         }
         if (!current_signal.hit_tp2) {                          //--- Check TP2
            bool tp2_hit = false;                                //--- Init hit
            if (current_signal.pos_type == 1 && bid >= current_signal.tp2) tp2_hit = true; //--- Buy hit
            if (current_signal.pos_type == -1 && ask <= current_signal.tp2) tp2_hit = true; //--- Sell hit
            if (tp2_hit) {                                       //--- Hit
               current_signal.hit_tp2 = true;                    //--- Set hit
               DrawTPHit(2, TimeCurrent(), current_signal.tp2, tp2_points); //--- Draw hit
            }
         }
         if (!current_signal.hit_tp3) {                          //--- Check TP3
            bool tp3_hit = false;                                //--- Init hit
            if (current_signal.pos_type == 1 && bid >= current_signal.tp3) tp3_hit = true; //--- Buy hit
            if (current_signal.pos_type == -1 && ask <= current_signal.tp3) tp3_hit = true; //--- Sell hit
            if (tp3_hit) {                                       //--- Hit
               current_signal.hit_tp3 = true;                    //--- Set hit
               DrawTPHit(3, TimeCurrent(), current_signal.tp3, tp3_points); //--- Draw hit
               if (trade_mode == Visual_Only) {                  //--- Check visual only
                  double close_price = (current_signal.pos_type == 1) ? bid : ask; //--- Get close
                  CloseVirtualPosition(close_price, false);      //--- Close virtual
               }
            }
         }
         // SL hit check for Visual_Only or manual if needed
         bool sl_hit = false;                                    //--- Init SL hit
         if (current_signal.pos_type == 1 && bid <= current_signal.sl) sl_hit = true; //--- Buy SL
         if (current_signal.pos_type == -1 && ask >= current_signal.sl) sl_hit = true; //--- Sell SL
         if (sl_hit && !current_signal.hit_sl) {                 //--- Check hit and not set
            bool already_won = false;                            //--- Init won flag
            switch(tp_level) {                                   //--- Check level
               case Level_1: already_won = current_signal.hit_tp1; break; //--- TP1 won
               case Level_2: already_won = current_signal.hit_tp2; break; //--- TP2 won
               case Level_3: already_won = current_signal.hit_tp3; break; //--- TP3 won
            }
            if (!already_won) {                                  //--- Check not won
               current_signal.hit_sl = true;                     //--- Set SL hit
               DrawSLHit(TimeCurrent(), current_signal.sl);      //--- Draw SL
            }
            if (trade_mode == Visual_Only) {                     //--- Check visual
               double close_price = (current_signal.pos_type == 1) ? bid : ask; //--- Get close
               CloseVirtualPosition(close_price, false);         //--- Close virtual
            }
         }
      }
   }
   UpdateDashboard();                                             //--- Update dashboard
}

//+------------------------------------------------------------------+
//| Get close price from history for auto-closed position            |
//+------------------------------------------------------------------+
double GetPositionClosePrice(long ticket) {
   HistorySelectByPosition(ticket);                               //--- Select history
   int deals = HistoryDealsTotal();                               //--- Get deals count
   if (deals > 0) {                                               //--- Check deals
      ulong deal_ticket = HistoryDealGetTicket(deals - 1);        //--- Get last deal
      return HistoryDealGetDouble(deal_ticket, DEAL_PRICE);       //--- Return price
   }
   return 0.0;                                                    //--- Return fallback
}

//+------------------------------------------------------------------+
//| Open virtual position                                            |
//+------------------------------------------------------------------+
void OpenVirtualPosition(int type, datetime ent_time, double ent_price) {
   current_signal.active = true;                                  //--- Set active
   current_signal.pos_type = type;                                //--- Set type
   current_signal.entry_time = ent_time;                          //--- Set time
   current_signal.entry_price = ent_price;                        //--- Set price
   current_signal.tp1 = ent_price + (tp1_points * _Point) * type; //--- Set TP1
   current_signal.tp2 = ent_price + (tp2_points * _Point) * type; //--- Set TP2
   current_signal.tp3 = ent_price + (tp3_points * _Point) * type; //--- Set TP3
   current_signal.sl = ent_price - (sl_points * _Point) * type;   //--- Set SL
   current_signal.hit_tp1 = false;                                //--- Reset TP1 hit
   current_signal.hit_tp2 = false;                                //--- Reset TP2 hit
   current_signal.hit_tp3 = false;                                //--- Reset TP3 hit
   current_signal.hit_sl = false;                                 //--- Reset SL hit
   current_signal.close_time = 0;                                 //--- Reset close time
   position_ticket = -1;                                          //--- Reset ticket
   DrawInitialLevels();                                           //--- Draw levels
}

//+------------------------------------------------------------------+
//| Close virtual position                                           |
//+------------------------------------------------------------------+
void CloseVirtualPosition(double close_price, bool is_early) {
   if (!current_signal.active) return;                            //--- Return if not active
   double profit_pts = (close_price - current_signal.entry_price) / _Point * current_signal.pos_type; //--- Calc profit
   current_signal.close_time = TimeCurrent();                     //--- Set close time
   if (is_early) {                                                //--- Check early
      DrawEarlyClose(TimeCurrent(), close_price, profit_pts);     //--- Draw early close
      if (trade_mode == Open_Trades && position_ticket != -1) {   //--- Check open trades
         MqlTradeRequest close_request = {};                      //--- Close request
         MqlTradeResult close_result = {};                        //--- Close result
         close_request.action = TRADE_ACTION_DEAL;                //--- Set action
         close_request.symbol = _Symbol;                          //--- Set symbol
         close_request.volume = 0.1;                              //--- Set volume
         close_request.type = (current_signal.pos_type == 1) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; //--- Set type
         close_request.price = close_price;                       //--- Set price
         close_request.deviation = 3;                             //--- Set deviation
         close_request.position = position_ticket;                 //--- Set position
         if (!OrderSend(close_request, close_result)) {           //--- Send close
            Print("Failed to close trade: ", GetLastError());     //--- Log error
         }
         position_ticket = -1;                                    //--- Reset ticket
      }
   }
   if (trade_mode == Open_Trades) {                               //--- Check open trades
      bool hit_selected_tp = false;                                //--- Init selected TP
      switch(tp_level) {                                           //--- Select TP
         case Level_1: hit_selected_tp = current_signal.hit_tp1; break; //--- TP1
         case Level_2: hit_selected_tp = current_signal.hit_tp2; break; //--- TP2
         case Level_3: hit_selected_tp = current_signal.hit_tp3; break; //--- TP3
      }
      bool count_it = current_signal.hit_sl || hit_selected_tp || !is_early; //--- Check count
      if (count_it) {                                              //--- Count
         total_profit_points += profit_pts;                         //--- Add profit
         total_signals++;                                          //--- Increment signals
         if (profit_pts > 0) wins++;                               //--- Increment wins
         else losses++;                                            //--- Increment losses
      }
   } else {                                                       //--- Visual only
      bool hit_selected = false;                                   //--- Init selected hit
      int selected_points = 0;                                     //--- Init points
      switch(tp_level) {                                           //--- Select TP
         case Level_1: hit_selected = current_signal.hit_tp1; selected_points = tp1_points; break; //--- TP1
         case Level_2: hit_selected = current_signal.hit_tp2; selected_points = tp2_points; break; //--- TP2
         case Level_3: hit_selected = current_signal.hit_tp3; selected_points = tp3_points; break; //--- TP3
      }
      double effective_profit = 0.0;                               //--- Init effective profit
      if (hit_selected) {                                          //--- Check hit selected
         effective_profit = (double)selected_points;               //--- Set to selected points
      } else if (current_signal.hit_sl) {                          //--- Check SL hit
         effective_profit = - (double)sl_points;                   //--- Set to -SL
      } else {                                                     //--- Else
         effective_profit = profit_pts;                            //--- Set to profit pts
      }
      total_profit_points += effective_profit;                      //--- Add effective profit
      total_signals++;                                             //--- Increment signals
      if (hit_selected || effective_profit > 0) wins++;            //--- Increment wins
      else losses++;                                               //--- Increment losses
   }
   current_signal.active = false;                                 //--- Deactivate
}

//+------------------------------------------------------------------+
//| Draw initial TP and SL visuals                                   |
//+------------------------------------------------------------------+
void DrawInitialLevels() {
   datetime entry_tm = current_signal.entry_time;                 //--- Entry time
   datetime bubble_tm = entry_tm;                                 //--- Bubble time
   datetime points_tm = bubble_tm;                                //--- Points time
   // TP1
   string prefix = "Initial_TP1_" + TimeToString(entry_tm) + "_"; //--- TP1 prefix
   color tp_color = clrBlue;                                      //--- TP color
   double hit_pr = current_signal.tp1;                            //--- TP1 price
   int pts = tp1_points;                                          //--- TP1 points
   char bubble_code = (char)140;                                  //--- Bubble code
   string bubble_name = prefix + "Bubble";                        //--- Bubble name
   ObjectCreate(0, bubble_name, OBJ_TEXT, 0, bubble_tm, hit_pr);  //--- Create bubble
   ObjectSetString(0, bubble_name, OBJPROP_TEXT, CharToString(bubble_code)); //--- Set text
   ObjectSetString(0, bubble_name, OBJPROP_FONT, "Wingdings");    //--- Set font
   ObjectSetInteger(0, bubble_name, OBJPROP_COLOR, tp_color);     //--- Set color
   ObjectSetInteger(0, bubble_name, OBJPROP_FONTSIZE, 12);        //--- Set size
   ObjectSetInteger(0, bubble_name, OBJPROP_ANCHOR, ANCHOR_LEFT); //--- Set anchor
   string points_name = prefix + "Points";                        //--- Points name
   ObjectCreate(0, points_name, OBJ_TEXT, 0, points_tm, hit_pr);  //--- Create points
   ObjectSetString(0, points_name, OBJPROP_TEXT, "+" + IntegerToString(pts)); //--- Set text
   ObjectSetInteger(0, points_name, OBJPROP_COLOR, tp_color);     //--- Set color
   ObjectSetInteger(0, points_name, OBJPROP_FONTSIZE, 10);        //--- Set size
   ObjectSetInteger(0, points_name, OBJPROP_ANCHOR, ANCHOR_RIGHT); //--- Set anchor
   // TP2
   prefix = "Initial_TP2_" + TimeToString(entry_tm) + "_";        //--- TP2 prefix
   hit_pr = current_signal.tp2;                                   //--- TP2 price
   pts = tp2_points;                                              //--- TP2 points
   bubble_code = (char)141;                                       //--- Bubble code
   bubble_name = prefix + "Bubble";                               //--- Bubble name
   ObjectCreate(0, bubble_name, OBJ_TEXT, 0, bubble_tm, hit_pr);  //--- Create bubble
   ObjectSetString(0, bubble_name, OBJPROP_TEXT, CharToString(bubble_code)); //--- Set text
   ObjectSetString(0, bubble_name, OBJPROP_FONT, "Wingdings");    //--- Set font
   ObjectSetInteger(0, bubble_name, OBJPROP_COLOR, tp_color);     //--- Set color
   ObjectSetInteger(0, bubble_name, OBJPROP_FONTSIZE, 12);        //--- Set size
   ObjectSetInteger(0, bubble_name, OBJPROP_ANCHOR, ANCHOR_LEFT); //--- Set anchor
   points_name = prefix + "Points";                               //--- Points name
   ObjectCreate(0, points_name, OBJ_TEXT, 0, points_tm, hit_pr);  //--- Create points
   ObjectSetString(0, points_name, OBJPROP_TEXT, "+" + IntegerToString(pts)); //--- Set text
   ObjectSetInteger(0, points_name, OBJPROP_COLOR, tp_color);     //--- Set color
   ObjectSetInteger(0, points_name, OBJPROP_FONTSIZE, 10);        //--- Set size
   ObjectSetInteger(0, points_name, OBJPROP_ANCHOR, ANCHOR_RIGHT); //--- Set anchor
   // TP3
   prefix = "Initial_TP3_" + TimeToString(entry_tm) + "_";        //--- TP3 prefix
   hit_pr = current_signal.tp3;                                   //--- TP3 price
   pts = tp3_points;                                              //--- TP3 points
   bubble_code = (char)142;                                       //--- Bubble code
   bubble_name = prefix + "Bubble";                               //--- Bubble name
   ObjectCreate(0, bubble_name, OBJ_TEXT, 0, bubble_tm, hit_pr);  //--- Create bubble
   ObjectSetString(0, bubble_name, OBJPROP_TEXT, CharToString(bubble_code)); //--- Set text
   ObjectSetString(0, bubble_name, OBJPROP_FONT, "Wingdings");    //--- Set font
   ObjectSetInteger(0, bubble_name, OBJPROP_COLOR, tp_color);     //--- Set color
   ObjectSetInteger(0, bubble_name, OBJPROP_FONTSIZE, 12);        //--- Set size
   ObjectSetInteger(0, bubble_name, OBJPROP_ANCHOR, ANCHOR_LEFT); //--- Set anchor
   points_name = prefix + "Points";                               //--- Points name
   ObjectCreate(0, points_name, OBJ_TEXT, 0, points_tm, hit_pr);  //--- Create points
   ObjectSetString(0, points_name, OBJPROP_TEXT, "+" + IntegerToString(pts)); //--- Set text
   ObjectSetInteger(0, points_name, OBJPROP_COLOR, tp_color);     //--- Set color
   ObjectSetInteger(0, points_name, OBJPROP_FONTSIZE, 10);        //--- Set size
   ObjectSetInteger(0, points_name, OBJPROP_ANCHOR, ANCHOR_RIGHT); //--- Set anchor
   // SL
   prefix = "Initial_SL_" + TimeToString(entry_tm) + "_";         //--- SL prefix
   hit_pr = current_signal.sl;                                    //--- SL price
   color sl_color = clrMagenta;                                   //--- SL color
   pts = sl_points;                                               //--- SL points
   bubble_code = (char)164;                                       //--- Bubble code
   bubble_name = prefix + "Bubble";                               //--- Bubble name
   ObjectCreate(0, bubble_name, OBJ_TEXT, 0, bubble_tm, hit_pr);  //--- Create bubble
   ObjectSetString(0, bubble_name, OBJPROP_TEXT, CharToString(bubble_code)); //--- Set text
   ObjectSetString(0, bubble_name, OBJPROP_FONT, "Wingdings");    //--- Set font
   ObjectSetInteger(0, bubble_name, OBJPROP_COLOR, sl_color);     //--- Set color
   ObjectSetInteger(0, bubble_name, OBJPROP_FONTSIZE, 12);        //--- Set size
   ObjectSetInteger(0, bubble_name, OBJPROP_ANCHOR, ANCHOR_LEFT); //--- Set anchor
   points_name = prefix + "Points";                               //--- Points name
   ObjectCreate(0, points_name, OBJ_TEXT, 0, points_tm, hit_pr);  //--- Create points
   ObjectSetString(0, points_name, OBJPROP_TEXT, "-" + IntegerToString(pts)); //--- Set text
   ObjectSetInteger(0, points_name, OBJPROP_COLOR, sl_color);     //--- Set color
   ObjectSetInteger(0, points_name, OBJPROP_FONTSIZE, 10);        //--- Set size
   ObjectSetInteger(0, points_name, OBJPROP_ANCHOR, ANCHOR_RIGHT); //--- Set anchor
}

//+------------------------------------------------------------------+
//| Draw TP hit visuals                                              |
//+------------------------------------------------------------------+
void DrawTPHit(int tp_num, datetime hit_tm, double hit_pr, int pts) {
   string prefix = "Signal_TP" + IntegerToString(tp_num) + "_" + TimeToString(current_signal.entry_time) + "_"; //--- Prefix
   color tp_color = clrBlue;                                      //--- TP color
   createTrendline(prefix + "DottedLine", current_signal.entry_time, current_signal.entry_price, hit_tm, hit_pr, clrDarkGray, STYLE_DOT, true, false); //--- Draw dotted
   createTrendline(prefix + "Connect", current_signal.entry_time, hit_pr, hit_tm, hit_pr, clrDarkGray, STYLE_SOLID, true, false); //--- Draw connect
   string tick_name = prefix + "Tick";                            //--- Tick name
   ObjectCreate(0, tick_name, OBJ_TEXT, 0, hit_tm, hit_pr);       //--- Create tick
   ObjectSetString(0, tick_name, OBJPROP_TEXT, CharToString((char)254)); //--- Set text
   ObjectSetString(0, tick_name, OBJPROP_FONT, "Wingdings");      //--- Set font
   ObjectSetInteger(0, tick_name, OBJPROP_COLOR, tp_color);       //--- Set color
   ObjectSetInteger(0, tick_name, OBJPROP_FONTSIZE, 12);          //--- Set size
   ObjectSetInteger(0, tick_name, OBJPROP_ANCHOR, ANCHOR_CENTER); //--- Set anchor
}

//+------------------------------------------------------------------+
//| Draw SL hit visuals                                              |
//+------------------------------------------------------------------+
void DrawSLHit(datetime hit_tm, double hit_pr) {
   string prefix = "Signal_SL_" + TimeToString(current_signal.entry_time) + "_"; //--- Prefix
   color sl_color = clrMagenta;                                   //--- SL color
   createTrendline(prefix + "DottedLine", current_signal.entry_time, current_signal.entry_price, hit_tm, hit_pr, clrDarkGray, STYLE_DOT, true, false); //--- Draw dotted
   createTrendline(prefix + "Connect", current_signal.entry_time, hit_pr, hit_tm, hit_pr, clrDarkGray, STYLE_SOLID, true, false); //--- Draw connect
   string tick_name = prefix + "Tick";                            //--- Tick name
   ObjectCreate(0, tick_name, OBJ_TEXT, 0, hit_tm, hit_pr);       //--- Create tick
   ObjectSetString(0, tick_name, OBJPROP_TEXT, CharToString((char)253)); //--- Set text
   ObjectSetString(0, tick_name, OBJPROP_FONT, "Wingdings");      //--- Set font
   ObjectSetInteger(0, tick_name, OBJPROP_COLOR, sl_color);       //--- Set color
   ObjectSetInteger(0, tick_name, OBJPROP_FONTSIZE, 12);          //--- Set size
   ObjectSetInteger(0, tick_name, OBJPROP_ANCHOR, ANCHOR_CENTER); //--- Set anchor
}

//+------------------------------------------------------------------+
//| Draw early close visuals                                         |
//+------------------------------------------------------------------+
void DrawEarlyClose(datetime hit_tm, double hit_pr, double pts) {
   string prefix = "Signal_Close_" + TimeToString(current_signal.entry_time) + "_"; //--- Prefix
   color close_color = (pts > 0) ? clrBlue : clrMagenta;          //--- Close color
   createTrendline(prefix + "DottedLine", current_signal.entry_time, current_signal.entry_price, hit_tm, hit_pr, clrDarkGray, STYLE_DOT, true, false); //--- Draw dotted
   datetime bubble_tm = current_signal.entry_time;                //--- Bubble time
   char bubble_code = (char)214;                                  //--- Bubble code
   string bubble_name = prefix + "Bubble";                        //--- Bubble name
   ObjectCreate(0, bubble_name, OBJ_TEXT, 0, bubble_tm, hit_pr);  //--- Create bubble
   ObjectSetString(0, bubble_name, OBJPROP_TEXT, CharToString(bubble_code)); //--- Set text
   ObjectSetString(0, bubble_name, OBJPROP_FONT, "Wingdings");    //--- Set font
   ObjectSetInteger(0, bubble_name, OBJPROP_COLOR, close_color);  //--- Set color
   ObjectSetInteger(0, bubble_name, OBJPROP_FONTSIZE, 12);        //--- Set size
   ObjectSetInteger(0, bubble_name, OBJPROP_ANCHOR, ANCHOR_LEFT); //--- Set anchor
   datetime points_tm = bubble_tm;                                //--- Points time
   string sign = (pts > 0) ? "+" : "";                            //--- Sign
   string points_text = sign + DoubleToString(pts, 0);            //--- Points text
   string points_name = prefix + "Points";                        //--- Points name
   ObjectCreate(0, points_name, OBJ_TEXT, 0, points_tm, hit_pr);  //--- Create points
   ObjectSetString(0, points_name, OBJPROP_TEXT, points_text);    //--- Set text
   ObjectSetInteger(0, points_name, OBJPROP_COLOR, close_color);  //--- Set color
   ObjectSetInteger(0, points_name, OBJPROP_FONTSIZE, 10);        //--- Set size
   ObjectSetInteger(0, points_name, OBJPROP_ANCHOR, ANCHOR_RIGHT); //--- Set anchor
   createTrendline(prefix + "Connect", bubble_tm, hit_pr, hit_tm, hit_pr, clrDarkGray, STYLE_SOLID, true, false); //--- Draw connect
}

//+------------------------------------------------------------------+
//| Create dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard() {
   int panel_x = dash_x;                                          //--- Panel X
   int panel_y = dash_y;                                          //--- Panel Y
   int panel_w = 250;                                             //--- Panel width
   int panel_h = 350;                                             //--- Panel height
   color bg_color = clrNavy;                                      //--- BG color
   color border_color = clrRoyalBlue;                             //--- Border color
   string space = " ";                                            //--- Space string
   createRecLabel(dash_prefix + "Panel", panel_x, panel_y, panel_w, panel_h, bg_color, 1, border_color, BORDER_FLAT); //--- Create panel
   color header_bg = clrMidnightBlue;                             //--- Header BG
   createRecLabel(dash_prefix + "HeaderPanel", panel_x + 1, panel_y + 1, panel_w - 2, 40, header_bg, 0, clrNONE, BORDER_FLAT); //--- Create header
   int rel_y = 7;                                                 //--- Relative Y
   createLabel(dash_prefix + "Header", panel_x + 15, panel_y + rel_y, "Strategy Tracker Dashboard", clrMediumSpringGreen, 12, "Arial Bold"); //--- Create header label
   rel_y += 30;                                                   //--- Increment Y
   color signal_bg = clrDarkSlateBlue;                            //--- Signal BG
   int signal_height = 160;                                       //--- Signal height
   createRecLabel(dash_prefix + "SignalPanel", panel_x + 1, panel_y + rel_y - 10, panel_w - 2, signal_height, signal_bg, 0, clrNONE, BORDER_FLAT); //--- Create signal panel
   createLabel(dash_prefix + "SignalHeader", panel_x + 10, panel_y + rel_y, "Current Signal", clrLightCyan, 11, "Arial Bold"); //--- Create signal header
   rel_y += 25;                                                   //--- Increment Y
   createLabel(dash_prefix + "SymbolLabel", panel_x + 10, panel_y + rel_y, "Symbol:", clrWhite, 10, "Arial Bold"); //--- Create symbol label
   createLabel(dash_prefix + "SymbolValue", panel_x + 100, panel_y + rel_y, _Symbol+" "+StringSubstr(EnumToString(_Period),7), clrDeepSkyBlue, 10, "Arial Bold"); //--- Create symbol value
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "DirectionLabel", panel_x + 10, panel_y + rel_y, "Signal:", clrWhite, 10, "Arial Bold"); //--- Create direction label
   createLabel(dash_prefix + "EntryPrice", panel_x + 100, panel_y + rel_y, space, clrWhite, 10, "Arial Bold"); //--- Create entry price
   createLabel(dash_prefix + "DirectionValue", panel_x + 200, panel_y + rel_y, space, clrWhite, 12, "Wingdings"); //--- Create direction value
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "TP1Label", panel_x + 10, panel_y + rel_y, "TP1:", clrWhite, 10, "Arial Bold"); //--- Create TP1 label
   createLabel(dash_prefix + "TP1Value", panel_x + 100, panel_y + rel_y, space, clrWhite, 10, "Arial"); //--- Create TP1 value
   createLabel(dash_prefix + "TP1Icon", panel_x + 200, panel_y + rel_y, space, clrWhite, 12, "Wingdings"); //--- Create TP1 icon
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "TP2Label", panel_x + 10, panel_y + rel_y, "TP2:", clrWhite, 10, "Arial Bold"); //--- Create TP2 label
   createLabel(dash_prefix + "TP2Value", panel_x + 100, panel_y + rel_y, space, clrWhite, 10, "Arial"); //--- Create TP2 value
   createLabel(dash_prefix + "TP2Icon", panel_x + 200, panel_y + rel_y, space, clrWhite, 12, "Wingdings"); //--- Create TP2 icon
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "TP3Label", panel_x + 10, panel_y + rel_y, "TP3:", clrWhite, 10, "Arial Bold"); //--- Create TP3 label
   createLabel(dash_prefix + "TP3Value", panel_x + 100, panel_y + rel_y, space, clrWhite, 10, "Arial"); //--- Create TP3 value
   createLabel(dash_prefix + "TP3Icon", panel_x + 200, panel_y + rel_y, space, clrWhite, 12, "Wingdings"); //--- Create TP3 icon
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "SLLabel", panel_x + 10, panel_y + rel_y, "SL:", clrWhite, 10, "Arial Bold"); //--- Create SL label
   createLabel(dash_prefix + "SLValue", panel_x + 100, panel_y + rel_y, space, clrWhite, 10, "Arial"); //--- Create SL value
   createLabel(dash_prefix + "SLIcon", panel_x + 200, panel_y + rel_y, space, clrWhite, 12, "Wingdings"); //--- Create SL icon
   rel_y += 20;                                                   //--- Increment Y
   color stats_bg = clrIndigo;                                    //--- Stats BG
   int stats_height = 140;                                        //--- Stats height
   createRecLabel(dash_prefix + "StatsPanel", panel_x + 1, panel_y + rel_y + 3, panel_w - 2, stats_height, stats_bg, 0, clrNONE, BORDER_FLAT); //--- Create stats panel
   createLabel(dash_prefix + "StatsHeader", panel_x + 10, panel_y + rel_y + 10, "Statistics", clrLightCyan, 11, "Arial Bold"); //--- Create stats header
   rel_y += 25;                                                   //--- Increment Y
   createLabel(dash_prefix + "TotalLabel", panel_x + 10, panel_y + rel_y+10, "Total Signals:", clrWhite, 10, "Arial Bold"); //--- Create total label
   createLabel(dash_prefix + "TotalValue", panel_x + 150, panel_y + rel_y+10, space, clrWhite, 10, "Arial"); //--- Create total value
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "WinLossLabel", panel_x + 10, panel_y + rel_y+10, "Win/Loss:", clrWhite, 10, "Arial Bold"); //--- Create win/loss label
   createLabel(dash_prefix + "WinLossValue", panel_x + 150, panel_y + rel_y+10, space, clrWhite, 10, "Arial"); //--- Create win/loss value
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "AgeLabel", panel_x + 10, panel_y + rel_y+10, "Last Signal Age:", clrWhite, 10, "Arial Bold"); //--- Create age label
   createLabel(dash_prefix + "AgeValue", panel_x + 150, panel_y + rel_y+10, space, clrWhite, 10, "Arial"); //--- Create age value
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "ProfitLabel", panel_x + 10, panel_y + rel_y+10, "Profit in Points:", clrWhite, 10, "Arial Bold"); //--- Create profit label
   createLabel(dash_prefix + "ProfitValue", panel_x + 150, panel_y + rel_y+10, space, clrWhite, 10, "Arial"); //--- Create profit value
   rel_y += 20;                                                   //--- Increment Y
   createLabel(dash_prefix + "SuccessLabel", panel_x + 10, panel_y + rel_y+10, "Success Rate:", clrWhite, 10, "Arial Bold"); //--- Create success label
   createLabel(dash_prefix + "SuccessValue", panel_x + 150, panel_y + rel_y+10, space, clrWhite, 10, "Arial"); //--- Create success value
   rel_y += 20;                                                   //--- Increment Y
   color footer_bg = clrMidnightBlue;                             //--- Footer BG
   createRecLabel(dash_prefix + "FooterPanel", panel_x + 1, panel_y + rel_y + 5+10, panel_w - 2, 25, footer_bg, 0, clrNONE, BORDER_FLAT); //--- Create footer
   createLabel(dash_prefix + "Footer", panel_x + 30, panel_y + rel_y + 10+10, "Copyright 2025, Allan Munene Mutiiria.", clrYellow, 8, "Arial"); //--- Create footer label
}

//+------------------------------------------------------------------+
//| Update dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard() {
   string space = " ";                                            //--- Space string
   bool display_signal = current_signal.active || current_signal.hit_tp1 || current_signal.hit_tp2 || current_signal.hit_tp3 || current_signal.hit_sl; //--- Check display
   if (display_signal) {                                          //--- Display signal
      string arrow = (current_signal.pos_type == 1) ? CharToString((char)233) : CharToString((char)234); //--- Arrow char
      color dir_color = (current_signal.pos_type == 1) ? clrLime : clrRed; //--- Direction color
      ObjectSetString(0, dash_prefix + "DirectionValue", OBJPROP_TEXT, arrow); //--- Set direction text
      ObjectSetInteger(0, dash_prefix + "DirectionValue", OBJPROP_COLOR, dir_color); //--- Set color
      color level_color = (current_signal.pos_type == 1) ? clrLime : clrRed; //--- Level color
      string direction = (current_signal.pos_type == 1) ? "BUY " : "SELL "; //--- Direction string
      ObjectSetString(0, dash_prefix + "EntryPrice", OBJPROP_TEXT, direction + DoubleToString(current_signal.entry_price, _Digits)); //--- Set entry text
      ObjectSetInteger(0, dash_prefix + "EntryPrice", OBJPROP_COLOR, level_color); //--- Set color
      ObjectSetString(0, dash_prefix + "TP1Value", OBJPROP_TEXT, DoubleToString(current_signal.tp1, _Digits)); //--- Set TP1 text
      ObjectSetInteger(0, dash_prefix + "TP1Value", OBJPROP_COLOR, clrWhite); //--- Set color
      ObjectSetString(0, dash_prefix + "TP2Value", OBJPROP_TEXT, DoubleToString(current_signal.tp2, _Digits)); //--- Set TP2 text
      ObjectSetInteger(0, dash_prefix + "TP2Value", OBJPROP_COLOR, clrWhite); //--- Set color
      ObjectSetString(0, dash_prefix + "TP3Value", OBJPROP_TEXT, DoubleToString(current_signal.tp3, _Digits)); //--- Set TP3 text
      ObjectSetInteger(0, dash_prefix + "TP3Value", OBJPROP_COLOR, clrWhite); //--- Set color
      ObjectSetString(0, dash_prefix + "SLValue", OBJPROP_TEXT, DoubleToString(current_signal.sl, _Digits)); //--- Set SL text
      ObjectSetInteger(0, dash_prefix + "SLValue", OBJPROP_COLOR, clrWhite); //--- Set color
      int tp1_icon = current_signal.hit_tp1 ? 252 : 183;             //--- TP1 icon
      color tp1_icon_color = current_signal.hit_tp1 ? clrLime : clrWhite; //--- TP1 color
      ObjectSetString(0, dash_prefix + "TP1Icon", OBJPROP_TEXT, CharToString((char)tp1_icon)); //--- Set TP1 icon
      ObjectSetInteger(0, dash_prefix + "TP1Icon", OBJPROP_COLOR, tp1_icon_color); //--- Set color
      int tp2_icon = current_signal.hit_tp2 ? 252 : 183;             //--- TP2 icon
      color tp2_icon_color = current_signal.hit_tp2 ? clrLime : clrWhite; //--- TP2 color
      ObjectSetString(0, dash_prefix + "TP2Icon", OBJPROP_TEXT, CharToString((char)tp2_icon)); //--- Set TP2 icon
      ObjectSetInteger(0, dash_prefix + "TP2Icon", OBJPROP_COLOR, tp2_icon_color); //--- Set color
      int tp3_icon = current_signal.hit_tp3 ? 252 : 183;             //--- TP3 icon
      color tp3_icon_color = current_signal.hit_tp3 ? clrLime : clrWhite; //--- TP3 color
      ObjectSetString(0, dash_prefix + "TP3Icon", OBJPROP_TEXT, CharToString((char)tp3_icon)); //--- Set TP3 icon
      ObjectSetInteger(0, dash_prefix + "TP3Icon", OBJPROP_COLOR, tp3_icon_color); //--- Set color
      int sl_icon = current_signal.hit_sl ? 251 : 183;               //--- SL icon
      color sl_icon_color = current_signal.hit_sl ? clrRed : clrWhite; //--- SL color
      ObjectSetString(0, dash_prefix + "SLIcon", OBJPROP_TEXT, CharToString((char)sl_icon)); //--- Set SL icon
      ObjectSetInteger(0, dash_prefix + "SLIcon", OBJPROP_COLOR, sl_icon_color); //--- Set color
      int entry_shift = iBarShift(_Symbol, PERIOD_CURRENT, current_signal.entry_time, false); //--- Entry shift
      int calc_shift = 0;                                    //--- Init calc shift
      if (!current_signal.active && current_signal.close_time != 0) { //--- Check closed
         calc_shift = iBarShift(_Symbol, PERIOD_CURRENT, current_signal.close_time, false); //--- Close shift
      }
      int age = entry_shift - calc_shift;                    //--- Calc age
      ObjectSetString(0, dash_prefix + "AgeValue", OBJPROP_TEXT, IntegerToString(age) + " bars"); //--- Set age text
   } else {                                                       //--- No signal
      ObjectSetString(0, dash_prefix + "DirectionValue", OBJPROP_TEXT, space); //--- Clear direction
      ObjectSetString(0, dash_prefix + "EntryPrice", OBJPROP_TEXT, space); //--- Clear entry
      ObjectSetString(0, dash_prefix + "TP1Value", OBJPROP_TEXT, space); //--- Clear TP1
      ObjectSetString(0, dash_prefix + "TP2Value", OBJPROP_TEXT, space); //--- Clear TP2
      ObjectSetString(0, dash_prefix + "TP3Value", OBJPROP_TEXT, space); //--- Clear TP3
      ObjectSetString(0, dash_prefix + "SLValue", OBJPROP_TEXT, space); //--- Clear SL
      ObjectSetString(0, dash_prefix + "AgeValue", OBJPROP_TEXT, space); //--- Clear age
      ObjectSetString(0, dash_prefix + "TP1Icon", OBJPROP_TEXT, space); //--- Clear TP1 icon
      ObjectSetString(0, dash_prefix + "TP2Icon", OBJPROP_TEXT, space); //--- Clear TP2 icon
      ObjectSetString(0, dash_prefix + "TP3Icon", OBJPROP_TEXT, space); //--- Clear TP3 icon
      ObjectSetString(0, dash_prefix + "SLIcon", OBJPROP_TEXT, space); //--- Clear SL icon
   }
   ObjectSetString(0, dash_prefix + "TotalValue", OBJPROP_TEXT, (string)total_signals); //--- Set total
   ObjectSetString(0, dash_prefix + "WinLossValue", OBJPROP_TEXT, (string)wins + " / " + (string)losses); //--- Set win/loss
   string profit_str = (total_profit_points > 0 ? "+" : "") + DoubleToString(total_profit_points, 0); //--- Profit string
   color profit_color = total_profit_points > 0 ? clrLime : (total_profit_points < 0 ? clrRed : clrWhite); //--- Profit color
   ObjectSetString(0, dash_prefix + "ProfitValue", OBJPROP_TEXT, profit_str); //--- Set profit text
   ObjectSetInteger(0, dash_prefix + "ProfitValue", OBJPROP_COLOR, profit_color); //--- Set color
   double success = (total_signals > 0) ? (double)wins / total_signals * 100.0 : 0.0; //--- Calc success
   ObjectSetString(0, dash_prefix + "SuccessValue", OBJPROP_TEXT, DoubleToString(success, 2) + "%"); //--- Set success
   ChartRedraw(0);                                                //--- Redraw chart
}
//+------------------------------------------------------------------+