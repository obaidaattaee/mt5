//+------------------------------------------------------------------+
//|                                          EmaBand_Complete_EA.mq5 |
//|                          Converted from Freqtrade emaband Strategy|
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Converted from Freqtrade"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters - استراتيجية كاملة                              |
//+------------------------------------------------------------------+

//--- Timeframe Settings
input ENUM_TIMEFRAMES Strategy_Timeframe = PERIOD_H1;     // إطار زمني للاستراتيجية (قابل للتعديل)
input ENUM_TIMEFRAMES Higher_Timeframe = PERIOD_D1;       // الإطار الزمني الأعلى (1d)

//--- EMA & MA Parameters
input int    EMA_Period = 21;                             // فترة EMA (emaperiod)
input int    MA_Period = 50;                              // فترة SMA (maperiod)

//--- Entry Parameters
input double Buy_Multiplier = 1.03;                       // معامل الشراء (buy_multiplier)
input double Sell_Multiplier = 0.97;                      // معامل البيع (sell_multiplier)

//--- Position Adjustment (Multi-buy)
input bool   Enable_Position_Adjustment = true;           // تفعيل الشراء المتعدد
input double Profit_Threshold = -0.05;                    // عتبة الربح للشراء الإضافي (-5%)
input double Max_Level_Increase = 0.25;                   // زيادة الحجم لكل مستوى (25%)
input double Max_Balance_Cap = 1000.0;                    // الحد الأقصى لرأس المال
input int    Cooldown_Period_Hours = 12;                  // فترة الانتظار بين عمليات الشراء (ساعات)

//--- Exit Tiers
input bool   Enable_Exit_Tiers = true;                    // تفعيل مستويات الخروج
input double Stop_Loss_Threshold = -0.70;                 // عتبة Stop Loss (-70%)
input int    Exit_Tier1_Min_Days = 0;                     // المستوى 1: الحد الأدنى للأيام
input int    Exit_Tier1_Max_Days = 7;                     // المستوى 1: الحد الأقصى للأيام
input double Exit_Tier1_Profit = 0.05;                    // المستوى 1: الربح المطلوب (5%)

input int    Exit_Tier2_Min_Days = 7;                     // المستوى 2: الحد الأدنى للأيام
input int    Exit_Tier2_Max_Days = 14;                    // المستوى 2: الحد الأقصى للأيام

//--- Standard Trading Parameters
input double Lot_Size = 0.1;                              // حجم الصفقة الأولية
input int    Stop_Loss_Pips = 500;                        // Stop Loss بالنقاط
input int    Take_Profit_Pips = 1000;                     // Take Profit بالنقاط
input int    Magic_Number = 789456;                       // Magic Number
input string Trade_Comment = "EmaBand";                   // تعليق الصفقة

//--- Trade Control
input bool   Enable_Buy = true;                           // تفعيل صفقات الشراء
input bool   Enable_Sell = true;                          // تفعيل صفقات البيع

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
int ema_low_handle;                                        // Handle: EMA Low (1d)
int ema_high_handle;                                       // Handle: EMA High (1d)
int sma_handle;                                            // Handle: SMA (1d)

double ema_low_buffer[];                                   // Buffer: EMA Low
double ema_high_buffer[];                                  // Buffer: EMA High
double sma_buffer[];                                       // Buffer: SMA

datetime last_bar_time = 0;                                // تتبع البار الجديد
datetime last_buy_time = 0;                                // آخر وقت شراء للـ cooldown

struct TradeInfo {
   ulong ticket;
   datetime open_time;
   double open_price;
   double initial_stake;
   int buy_count;
   double total_spent;
};

TradeInfo current_trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- إنشاء مؤشر EMA Low على الإطار الزمني الأعلى
   ema_low_handle = iMA(_Symbol, Higher_Timeframe, EMA_Period, 0, MODE_EMA, PRICE_LOW);
   if(ema_low_handle == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء EMA Low: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- إنشاء مؤشر EMA High على الإطار الزمني الأعلى
   ema_high_handle = iMA(_Symbol, Higher_Timeframe, EMA_Period, 0, MODE_EMA, PRICE_HIGH);
   if(ema_high_handle == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء EMA High: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- إنشاء مؤشر SMA على الإطار الزمني الأعلى
   sma_handle = iMA(_Symbol, Higher_Timeframe, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
   if(sma_handle == INVALID_HANDLE)
   {
      Print("❌ خطأ في إنشاء SMA: ", GetLastError());
      return(INIT_FAILED);
   }
   
   //--- تهيئة المصفوفات
   ArraySetAsSeries(ema_low_buffer, true);
   ArraySetAsSeries(ema_high_buffer, true);
   ArraySetAsSeries(sma_buffer, true);
   
   //--- تهيئة معلومات الصفقة
   ResetTradeInfo();
   
   //--- التحقق من Filling Mode المدعوم
   ENUM_SYMBOL_TRADE_EXECUTION exec_mode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
   string filling_info = "";
   
   if(exec_mode == SYMBOL_TRADE_EXECUTION_EXCHANGE)
      filling_info = "Exchange Mode (FOK/IOC/Return)";
   else if(exec_mode == SYMBOL_TRADE_EXECUTION_INSTANT)
      filling_info = "Instant Mode";
   else if(exec_mode == SYMBOL_TRADE_EXECUTION_MARKET)
      filling_info = "Market Mode (FOK/IOC)";
   else if(exec_mode == SYMBOL_TRADE_EXECUTION_REQUEST)
      filling_info = "Request Mode";
   
   //--- طباعة معلومات التهيئة
   Print("════════════════════════════════════════");
   Print("✅ EA تم تهيئته بنجاح");
   Print("════════════════════════════════════════");
   Print("📊 Symbol: ", _Symbol);
   Print("🔧 Execution Mode: ", filling_info);
   Print("⏱️ Strategy Timeframe: ", EnumToString(Strategy_Timeframe));
   Print("📅 Higher Timeframe: ", EnumToString(Higher_Timeframe));
   Print("📈 EMA Period: ", EMA_Period);
   Print("📊 SMA Period: ", MA_Period);
   Print("💹 Buy Multiplier: ", Buy_Multiplier);
   Print("💹 Sell Multiplier: ", Sell_Multiplier);
   Print("🔄 Position Adjustment: ", Enable_Position_Adjustment ? "Enabled" : "Disabled");
   Print("📉 Profit Threshold: ", Profit_Threshold * 100, "%");
   Print("⏳ Cooldown Period: ", Cooldown_Period_Hours, " hours");
   Print("════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- تحرير Handles
   if(ema_low_handle != INVALID_HANDLE) IndicatorRelease(ema_low_handle);
   if(ema_high_handle != INVALID_HANDLE) IndicatorRelease(ema_high_handle);
   if(sma_handle != INVALID_HANDLE) IndicatorRelease(sma_handle);
   
   Print("EA تم إيقافه - السبب: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- التحقق من البار الجديد على الإطار الزمني المحدد
   datetime current_bar_time = iTime(_Symbol, Strategy_Timeframe, 0);
   if(current_bar_time == last_bar_time)
      return;
   
   last_bar_time = current_bar_time;
   
   //--- نسخ بيانات المؤشرات
   if(CopyBuffer(ema_low_handle, 0, 0, 3, ema_low_buffer) < 3 ||
      CopyBuffer(ema_high_handle, 0, 0, 3, ema_high_buffer) < 3 ||
      CopyBuffer(sma_handle, 0, 0, 3, sma_buffer) < 3)
   {
      Print("❌ خطأ في نسخ بيانات المؤشرات");
      return;
   }
   
   //--- تحديث معلومات الصفقة الحالية
   UpdateCurrentTradeInfo();
   
   //--- الحصول على آخر سعر إغلاق
   double close_price = iClose(_Symbol, Strategy_Timeframe, 1);
   double prev_close = iClose(_Symbol, Strategy_Timeframe, 2);
   
   //--- قيم المؤشرات من الإطار الزمني الأعلى
   double ema_low_1d = ema_low_buffer[0];
   double ema_high_1d = ema_high_buffer[0];
   double sma_1d = sma_buffer[0];
   
   //--- populate_indicators
   double buy_price_indicator = ema_low_1d * Buy_Multiplier;
   double sell_price_indicator = ema_high_1d * Sell_Multiplier;
   
   //--- populate_entry_trend
   bool below_avg_low = close_price < buy_price_indicator;
   
   //--- populate_exit_trend
   bool sell_signal = close_price >= sell_price_indicator;
   
   //--- Custom Exit Logic
   if(current_trade.ticket > 0)
   {
      CheckCustomExit(close_price, sma_1d);
      
      //--- adjust_trade_position (Multi-buy)
      if(Enable_Position_Adjustment)
      {
         CheckPositionAdjustment(close_price, prev_close, buy_price_indicator);
      }
   }
   
   //--- إشارة الشراء
   if(Enable_Buy && below_avg_low && current_trade.ticket == 0)
   {
      Print("═══════════════════════════════════════");
      Print("🟢 إشارة شراء جديدة");
      Print("═══════════════════════════════════════");
      Print("💰 Close: ", close_price);
      Print("📊 EMA Low (1d): ", ema_low_1d);
      Print("📈 Buy Price: ", buy_price_indicator);
      Print("✅ Condition: ", close_price, " < ", buy_price_indicator);
      Print("═══════════════════════════════════════");
      
      OpenBuyOrder();
   }
   
   //--- إشارة البيع (Exit)
   if(Enable_Sell && sell_signal && current_trade.ticket > 0)
   {
      double current_profit = CalculateCurrentProfit(close_price);
      
      // confirm_trade_exit: لا تبيع بخسارة إذا كانت الإشارة ema_above_sell_long
      if(current_profit >= 0)
      {
         Print("═══════════════════════════════════════");
         Print("🔴 إشارة بيع (Exit Signal)");
         Print("═══════════════════════════════════════");
         Print("💰 Close: ", close_price);
         Print("📊 EMA High (1d): ", ema_high_1d);
         Print("📈 Sell Price: ", sell_price_indicator);
         Print("💹 Current Profit: ", current_profit * 100, "%");
         Print("═══════════════════════════════════════");
         
         ClosePosition("ema_above_sell_long");
      }
   }
}

//+------------------------------------------------------------------+
//| الحصول على Filling Mode المناسب للوسيط                             |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode()
{
   // الحصول على Filling Modes المدعومة
   int filling = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   
   // التحقق من الأوضاع المدعومة
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   
   // الافتراضي: Return
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| الحصول على وصف Return Code                                        |
//+------------------------------------------------------------------+
string GetRetcodeDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:           return "Requote";
      case TRADE_RETCODE_REJECT:            return "Request rejected";
      case TRADE_RETCODE_CANCEL:            return "Request canceled";
      case TRADE_RETCODE_PLACED:            return "Order placed";
      case TRADE_RETCODE_DONE:              return "Request completed";
      case TRADE_RETCODE_DONE_PARTIAL:      return "Request partially filled";
      case TRADE_RETCODE_ERROR:             return "Request processing error";
      case TRADE_RETCODE_TIMEOUT:           return "Request timeout";
      case TRADE_RETCODE_INVALID:           return "Invalid request";
      case TRADE_RETCODE_INVALID_VOLUME:    return "Invalid volume";
      case TRADE_RETCODE_INVALID_PRICE:     return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS:     return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED:    return "Trade disabled";
      case TRADE_RETCODE_MARKET_CLOSED:     return "Market closed";
      case TRADE_RETCODE_NO_MONEY:          return "Not enough money";
      case TRADE_RETCODE_PRICE_CHANGED:     return "Price changed";
      case TRADE_RETCODE_PRICE_OFF:         return "No quotes";
      case TRADE_RETCODE_INVALID_EXPIRATION:return "Invalid expiration";
      case TRADE_RETCODE_ORDER_CHANGED:     return "Order changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
      case TRADE_RETCODE_NO_CHANGES:        return "No changes";
      case TRADE_RETCODE_SERVER_DISABLES_AT:return "Autotrading disabled by server";
      case TRADE_RETCODE_CLIENT_DISABLES_AT:return "Autotrading disabled by client";
      case TRADE_RETCODE_LOCKED:            return "Request locked";
      case TRADE_RETCODE_FROZEN:            return "Order/Position frozen";
      case TRADE_RETCODE_INVALID_FILL:      return "Invalid filling type";
      case TRADE_RETCODE_CONNECTION:        return "No connection";
      case TRADE_RETCODE_ONLY_REAL:         return "Only for real accounts";
      case TRADE_RETCODE_LIMIT_ORDERS:      return "Limit orders reached";
      case TRADE_RETCODE_LIMIT_VOLUME:      return "Volume limit reached";
      default:                              return "Unknown error";
   }
}

//+------------------------------------------------------------------+
//| فتح أمر شراء                                                       |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   double sl = NormalizeDouble(ask - Stop_Loss_Pips * point * 10, digits);
   double tp = NormalizeDouble(ask + Take_Profit_Pips * point * 10, digits);
   
   //--- تحديد Filling Mode المناسب
   ENUM_ORDER_TYPE_FILLING filling = GetFillingMode();
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = Lot_Size;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = Magic_Number;
   request.comment = Trade_Comment + "_BUY";
   request.type_filling = filling;  // ✅ إضافة Filling Mode
   
   if(!OrderSend(request, result))
   {
      Print("❌ خطأ في فتح صفقة الشراء: ", GetLastError());
      Print("❌ Return Code: ", result.retcode, " - ", GetRetcodeDescription(result.retcode));
      Print("❌ Filling Mode Used: ", EnumToString(filling));
   }
   else
   {
      Print("✅ صفقة شراء تم فتحها!");
      Print("🎫 Ticket: ", result.order);
      Print("💰 Price: ", result.price);
      Print("📊 Volume: ", result.volume);
      
      //--- حفظ معلومات الصفقة
      current_trade.ticket = result.order;
      current_trade.open_time = TimeCurrent();
      current_trade.open_price = result.price;
      current_trade.initial_stake = Lot_Size;
      current_trade.buy_count = 1;
      current_trade.total_spent = Lot_Size;
      last_buy_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| التحقق من شروط الشراء الإضافي (Position Adjustment)               |
//+------------------------------------------------------------------+
void CheckPositionAdjustment(double current_price, double prev_close, double buy_price)
{
   if(current_trade.ticket == 0) return;
   
   //--- حساب الربح الحالي
   double current_profit = CalculateCurrentProfit(current_price);
   
   //--- شرط المستوى: الربح أقل من العتبة
   if(current_profit > Profit_Threshold)
      return;
   
   //--- شرط السعر: السعر الحالي أعلى من السابق
   double close_price = iClose(_Symbol, Strategy_Timeframe, 1);
   if(close_price <= prev_close)
      return;
   
   //--- شرط الوقت: Cooldown
   datetime current_time = TimeCurrent();
   int cooldown_seconds = Cooldown_Period_Hours * 3600;
   
   if(current_time - last_buy_time < cooldown_seconds)
   {
      int remaining = cooldown_seconds - (int)(current_time - last_buy_time);
      Print("⏳ Cooldown active. Remaining: ", remaining / 3600, " hours");
      return;
   }
   
   //--- حساب حجم الصفقة الجديد
   double stake_amount = current_trade.initial_stake * (1 + (current_trade.buy_count * Max_Level_Increase));
   
   //--- التحقق من الحد الأقصى لرأس المال
   if((current_trade.total_spent + stake_amount) > Max_Balance_Cap)
   {
      Print("⚠️ تجاوز الحد الأقصى لرأس المال");
      return;
   }
   
   Print("═══════════════════════════════════════");
   Print("🔄 شراء إضافي (Position Adjustment)");
   Print("═══════════════════════════════════════");
   Print("📉 Current Profit: ", current_profit * 100, "%");
   Print("📊 Buy Count: ", current_trade.buy_count);
   Print("💰 New Stake: ", stake_amount);
   Print("💵 Total Spent: ", current_trade.total_spent + stake_amount);
   Print("═══════════════════════════════════════");
   
   //--- فتح صفقة إضافية
   OpenAdditionalBuy(stake_amount);
}

//+------------------------------------------------------------------+
//| فتح صفقة شراء إضافية                                             |
//+------------------------------------------------------------------+
void OpenAdditionalBuy(double volume)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   double sl = NormalizeDouble(ask - Stop_Loss_Pips * point * 10, digits);
   double tp = NormalizeDouble(ask + Take_Profit_Pips * point * 10, digits);
   
   //--- تحديد Filling Mode المناسب
   ENUM_ORDER_TYPE_FILLING filling = GetFillingMode();
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = Magic_Number;
   request.comment = Trade_Comment + "_ADD";
   request.type_filling = filling;  // ✅ إضافة Filling Mode
   
   if(!OrderSend(request, result))
   {
      Print("❌ خطأ في فتح صفقة إضافية: ", GetLastError());
      Print("❌ Return Code: ", result.retcode, " - ", GetRetcodeDescription(result.retcode));
   }
   else
   {
      Print("✅ صفقة إضافية تم فتحها!");
      Print("🎫 Ticket: ", result.order);
      Print("💰 Price: ", result.price);
      Print("📊 Volume: ", result.volume);
      
      //--- تحديث معلومات الصفقة
      current_trade.buy_count++;
      current_trade.total_spent += volume;
      last_buy_time = TimeCurrent();
   }
}
   
   if(!OrderSend(request, result))
   {
      Print("❌ خطأ في فتح صفقة إضافية: ", GetLastError());
   }
   else
   {
      Print("✅ صفقة إضافية تم فتحها!");
      Print("🎫 Ticket: ", result.order);
      Print("💰 Price: ", result.price);
      Print("📊 Volume: ", result.volume);
      
      //--- تحديث معلومات الصفقة
      current_trade.buy_count++;
      current_trade.total_spent += volume;
      last_buy_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| التحقق من شروط الخروج المخصصة (Custom Exit)                      |
//+------------------------------------------------------------------+
void CheckCustomExit(double current_price, double sma_value)
{
   if(!Enable_Exit_Tiers) return;
   if(current_trade.ticket == 0) return;
   
   datetime current_time = TimeCurrent();
   int days_open = (int)((current_time - current_trade.open_time) / 86400);
   double current_profit = CalculateCurrentProfit(current_price);
   
   //--- Stop Loss Threshold
   if(current_profit < Stop_Loss_Threshold)
   {
      Print("🛑 Stop Loss Hit: ", current_profit * 100, "%");
      ClosePosition("stop_loss_" + IntegerToString((int)(Stop_Loss_Threshold * 100)));
      return;
   }
   
   //--- Exit Tier 1
   if(days_open >= Exit_Tier1_Min_Days && days_open < Exit_Tier1_Max_Days)
   {
      if(current_price > current_trade.open_price * (1 + Exit_Tier1_Profit))
      {
         Print("📊 Exit Tier 1 - Days: ", days_open, " Profit: ", current_profit * 100, "%");
         ClosePosition("exit_tier1_market");
         return;
      }
   }
   
   //--- Exit Tier 2 (avg_days)
   if(days_open >= Exit_Tier2_Min_Days && days_open < Exit_Tier2_Max_Days)
   {
      if(current_price > sma_value)
      {
         Print("📊 Exit Tier 2 - Price > SMA - Days: ", days_open);
         ClosePosition("exit_tier2_avg_days");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| إغلاق جميع الصفقات المفتوحة                                       |
//+------------------------------------------------------------------+
void ClosePosition(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         {
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            //--- تحديد Filling Mode المناسب
            ENUM_ORDER_TYPE_FILLING filling = GetFillingMode();
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            request.deviation = 10;
            request.magic = Magic_Number;
            request.comment = reason;
            request.type_filling = filling;  // ✅ إضافة Filling Mode
            
            if(OrderSend(request, result))
            {
               Print("✅ صفقة تم إغلاقها - السبب: ", reason);
            }
            else
            {
               Print("❌ خطأ في إغلاق الصفقة: ", GetLastError());
               Print("❌ Return Code: ", result.retcode, " - ", GetRetcodeDescription(result.retcode));
            }
         }
      }
   }
   
   ResetTradeInfo();
}

//+------------------------------------------------------------------+
//| حساب الربح الحالي                                                 |
//+------------------------------------------------------------------+
double CalculateCurrentProfit(double current_price)
{
   if(current_trade.ticket == 0 || current_trade.open_price == 0)
      return 0.0;
   
   return (current_price - current_trade.open_price) / current_trade.open_price;
}

//+------------------------------------------------------------------+
//| تحديث معلومات الصفقة الحالية                                      |
//+------------------------------------------------------------------+
void UpdateCurrentTradeInfo()
{
   bool has_position = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         {
            has_position = true;
            
            if(current_trade.ticket == 0)
            {
               current_trade.ticket = ticket;
               current_trade.open_time = (datetime)PositionGetInteger(POSITION_TIME);
               current_trade.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            }
            break;
         }
      }
   }
   
   if(!has_position)
   {
      ResetTradeInfo();
   }
}

//+------------------------------------------------------------------+
//| إعادة تعيين معلومات الصفقة                                        |
//+------------------------------------------------------------------+
void ResetTradeInfo()
{
   current_trade.ticket = 0;
   current_trade.open_time = 0;
   current_trade.open_price = 0;
   current_trade.initial_stake = 0;
   current_trade.buy_count = 0;
   current_trade.total_spent = 0;
}

//+------------------------------------------------------------------+
