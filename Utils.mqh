//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                       Copyright 2021, Homma.tech |
//|                                           https://www.homma.tech |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Homma.tech"
#property link      "https://www.homma.tech"

#include <Trade/Trade.mqh>
#include <Simplify/NewTypes.mqh>

class CUtils {
 private:
  double             pastClose;

 public:
  double CUtils :: CandleSize(ENUM_TIMEFRAMES u_timeframe = PERIOD_CURRENT, int u_shift = 1);
  bool CUtils :: IsCandlePositive(ENUM_TIMEFRAMES u_timeframe = PERIOD_CURRENT, int u_shift = 1);
  bool CUtils :: IsCandleNegative(ENUM_TIMEFRAMES u_timeframe = PERIOD_CURRENT, int u_shift = 1);
  void CUtils :: ExpertPositions(long magicNumber, ulong &tickets[]);
  void CUtils :: ArrayShift(int ut_shift, double &ut_buffer[]);

  CUtils ::          CUtils() {
    pastClose = 0;
  }

  //+------------------------------------------------------------------+
  //|  Acumulated profit function                                     |
  //+------------------------------------------------------------------+
  double CUtils :: AcumulatedProfit(datetime initDate_AP, datetime finishDate_AP) {
    double profitAcum = 0;

    HistorySelect(initDate_AP, finishDate_AP);
    for(int i = 1; i <= HistoryDealsTotal(); i++) {
      ulong ticket = HistoryDealGetTicket(i);
      profitAcum += HistoryDealGetDouble(ticket, DEAL_PROFIT);
    }
    if(PositionSelect(_Symbol)) {
      profitAcum += PositionGetDouble(POSITION_PROFIT);
    }

    return profitAcum;
  }

  //+------------------------------------------------------------------+
  //|  Close all positions function                                    |
  //+------------------------------------------------------------------+
  void CUtils ::     CloseAllPositions(string symbol, int deviation) {
    CTrade trade_TL;
    ulong ticket = 0;
    if(PositionSelect(symbol)) {
      for(int i = 0; i < PositionsTotal(); i++) {
        ticket = PositionGetTicket(i);
        trade_TL.PositionClose(ticket, deviation);
      }
    }
  }

  //+------------------------------------------------------------------+
  //|  Delete all orders function                                      |
  //+------------------------------------------------------------------+
  void CUtils ::     DeleteAllOrders() {
    CTrade trade_DAO;
    ulong ticket = 0;
    if(OrdersTotal() != 0) {
      for(int i = 0; i < OrdersTotal(); i++) {
        ticket = OrderGetTicket(i);
        trade_DAO.OrderDelete(ticket);
      }
    }
  }

  //+------------------------------------------------------------------+
  //|  Trainling stop function                                         |
  //+------------------------------------------------------------------+
  void CUtils :: TrailingStop (ulong ticket,
                               double stopLoss_,
                               double step = 0,
                               double startLevel = 0) {
    CTrade trade_TS;
    double newSL = 0;

    if(step == 0)
      step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) / _Point;

    if(PositionSelectByTicket(ticket)) {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
          PositionGetDouble(POSITION_PRICE_CURRENT) >= PositionGetDouble(POSITION_PRICE_OPEN) + startLevel * _Point) {
        newSL = PositionGetDouble(POSITION_PRICE_CURRENT) - stopLoss_ * _Point;
        if(newSL > PositionGetDouble(POSITION_SL))
          trade_TS.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
          PositionGetDouble(POSITION_PRICE_CURRENT) <= PositionGetDouble(POSITION_PRICE_OPEN) - startLevel * _Point) {
        newSL = PositionGetDouble(POSITION_PRICE_CURRENT) + stopLoss_ * _Point;
        if(newSL < PositionGetDouble(POSITION_SL))
          trade_TS.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
    }
  }

  //+------------------------------------------------------------------+
  //|  Breakeven function                                              |
  //+------------------------------------------------------------------+
  void CUtils :: Breakeven (ulong ticket,
                            double stopLoss_,
                            double step = NULL) {
    bool trailingControl = true;

    if(step == NULL)
      step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(PositionSelectByTicket(ticket)) {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
        if(PositionGetDouble(POSITION_SL) >= PositionGetDouble(POSITION_PRICE_OPEN))
          trailingControl = false;
      } else {
        if(PositionGetDouble(POSITION_SL) <= PositionGetDouble(POSITION_PRICE_OPEN))
          trailingControl = false;
      }
      if(trailingControl)
        TrailingStop(ticket, stopLoss_, step, 0);
    }
  }

  //+------------------------------------------------------------------+
  //|  Martingale function                                             |
  //+------------------------------------------------------------------+
  double CUtils :: Martingale (double factor,
                               TRADE_TYPE type,
                               double operationPrice,
                               double stopLoss_,
                               double takeProfit_) {
    CTrade trade_M;
    ulong ticket;
    uint total = 0;
    double lastVolume = 0, newVolume = 0;

    HistorySelect(0, TimeLocal());
    total = HistoryDealsTotal();

    ticket = HistoryDealGetTicket(total - 1);
    lastVolume = HistoryDealGetDouble(ticket, DEAL_VOLUME);

    HistoryDealGetInteger(ticket, DEAL_TYPE);
    newVolume = lastVolume * factor;
    if(type == BUY)
      trade_M.Buy(newVolume,
                  _Symbol,
                  operationPrice,
                  operationPrice - stopLoss_ * _Point,
                  operationPrice + takeProfit_ * _Point);
    if(type == SELL)
      trade_M.Sell(newVolume,
                   _Symbol,
                   operationPrice,
                   operationPrice + stopLoss_ * _Point,
                   operationPrice - takeProfit_ * _Point);
    return newVolume;
  }

  //+------------------------------------------------------------------+
  //|  Define stops for the manual oppened positions                   |
  //+------------------------------------------------------------------+
  bool CUtils ::     SetStopsForManual(double stopLoss_,
                                       double takeProfit_) {
    CTrade setStopForManual_trade;
    ulong ticket_;

    if(PositionSelect(_Symbol)) {
      ticket_ = PositionGetInteger(POSITION_TICKET);
      if(PositionGetInteger(POSITION_REASON) == POSITION_REASON_CLIENT) {
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
            (PositionGetDouble(POSITION_SL) != PositionGetDouble(POSITION_PRICE_OPEN) - (stopLoss_ * _Point) ||
             PositionGetDouble(POSITION_TP) != PositionGetDouble(POSITION_PRICE_OPEN) + (takeProfit_ * _Point))) {
          setStopForManual_trade.PositionModify(ticket_,
                                                PositionGetDouble(POSITION_PRICE_OPEN) - (stopLoss_ * _Point),
                                                PositionGetDouble(POSITION_PRICE_OPEN) + (takeProfit_ * _Point));
        }
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
            (PositionGetDouble(POSITION_SL) != PositionGetDouble(POSITION_PRICE_OPEN) + (stopLoss_ * _Point) ||
             PositionGetDouble(POSITION_TP) != PositionGetDouble(POSITION_PRICE_OPEN) - (takeProfit_ * _Point))) {
          setStopForManual_trade.PositionModify(ticket_,
                                                PositionGetDouble(POSITION_PRICE_OPEN) + (stopLoss_ * _Point),
                                                PositionGetDouble(POSITION_PRICE_OPEN) - (takeProfit_ * _Point));
        }
        return true;
      }
    }
    return false;
  }

  //+------------------------------------------------------------------+
  //|  Partial close a position based on percentage                    |
  //+------------------------------------------------------------------+
  bool CUtils ::     PartialClosePercent(ulong ticket,
                                         double percentageRemain,
                                         double levelExecute) {
    CTrade partialClose_trade;
    double volume;
    if(PositionSelectByTicket(ticket)) {
      volume = PositionGetDouble(POSITION_VOLUME);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
          PositionGetDouble(POSITION_PRICE_CURRENT) == PositionGetDouble(POSITION_PRICE_OPEN) + levelExecute * _Point) {
        partialClose_trade.Sell(NormalizeDouble(volume * percentageRemain, 0));
        return true;
      }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
          PositionGetDouble(POSITION_PRICE_CURRENT) == PositionGetDouble(POSITION_PRICE_OPEN) - levelExecute * _Point) {
        partialClose_trade.Buy(NormalizeDouble(volume * percentageRemain, 0));
        return true;
      }
    }
    return false;
  }

  //+------------------------------------------------------------------+
  //| Partial close a position based on volume                         |
  //+------------------------------------------------------------------+
  bool CUtils ::     PartialCloseAmount(ulong ticket,
                                        double volumeToClose,
                                        double levelExecute) {
    CTrade partialClose_trade;
    if(PositionSelectByTicket(ticket)) {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
          PositionGetDouble(POSITION_PRICE_CURRENT) == PositionGetDouble(POSITION_PRICE_OPEN) + levelExecute * _Point) {
        partialClose_trade.Sell(volumeToClose);
        return true;
      }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
          PositionGetDouble(POSITION_PRICE_CURRENT) == PositionGetDouble(POSITION_PRICE_OPEN) - levelExecute * _Point) {
        partialClose_trade.Buy(volumeToClose);
        return true;
      }
    }
    return false;
  }

  //+------------------------------------------------------------------+
  //|  Number of trades in a period function                           |
  //+------------------------------------------------------------------+
  int CUtils :: NumberOfTrades (datetime initDate, 
                                datetime finishDate) {
    HistorySelect(initDate, finishDate);
    return HistoryDealsTotal();
  }

  //+------------------------------------------------------------------+
  //|  Is new candle function                                          |
  //+------------------------------------------------------------------+
  bool CUtils ::     IsNewCandle(ENUM_TIMEFRAMES timeframe = 0) {
    if(pastClose != iClose(NULL, timeframe, 1)) {
      pastClose = iClose(NULL, timeframe, 1);
      return true;
    }
    pastClose = iClose(NULL, timeframe, 1);
    return false;
  }

  //+------------------------------------------------------------------+
  //|  Past ticket function                                            |
  //+------------------------------------------------------------------+
  ulong CUtils ::    PastOperationTicket(int shift) {
    uint dealsTotal;
    string today;

    today = TimeToString(TimeLocal(), TIME_DATE);

    HistorySelect(StringToTime(today), TimeCurrent());
    dealsTotal = HistoryDealsTotal();
    return HistoryDealGetTicket(dealsTotal - shift);
  }

  //+------------------------------------------------------------------+
  //|  Get deal type function                                          |
  //+------------------------------------------------------------------+
  TRADE_TYPE CUtils :: HistoryDealType(int shift) {
    ulong ticket;

    ticket = PastOperationTicket(shift);
    if(HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BUY)
      return BUY;
    if(HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_SELL)
      return SELL;
    return NOTHING;
  }

  //+------------------------------------------------------------------+
  //|  Get deal price function                                         |
  //+------------------------------------------------------------------+
  double CUtils ::   HistoryDealPrice(int shift) {
    ulong ticket;

    ticket = PastOperationTicket(shift);

    return HistoryDealGetDouble(ticket, DEAL_PRICE);
  }

  //+------------------------------------------------------------------+
  //|  Detects a position closed by TP                                 |
  //+------------------------------------------------------------------+
  bool CUtils ::     TPDetector() {
    ulong ticket = PastOperationTicket(1);
    if(HistoryDealGetInteger(ticket, DEAL_REASON) == DEAL_REASON_TP)
      return true;
    return false;
  }

  //+------------------------------------------------------------------+
  //|  Time tokenizer function                                         |
  //+------------------------------------------------------------------+
  void CUtils :: TimeStringTokenizer (string time, 
                                      string &tokenizedTime[]) {
    StringSplit(time, ':', tokenizedTime);
  }

  //+------------------------------------------------------------------+
  //|  String to timestamp function                                    |
  //+------------------------------------------------------------------+
  int CUtils :: StringTimeToInt (string time, 
                                 ENUM_TIME_STRING_TO_INT_TYPES selector) {
    string tokenizedTime[];
    int absoluteValueTime = 0;

    TimeStringTokenizer(time, tokenizedTime);

    switch (selector) {
    case   HHMMSS:
      absoluteValueTime = (int)(StringToInteger(tokenizedTime[0]) * 3600);
      absoluteValueTime += (int)(StringToInteger(tokenizedTime[1]) * 60);
      absoluteValueTime += (int)StringToInteger(tokenizedTime[2]);
      break;
    case     HHMM:
      absoluteValueTime = (int)(StringToInteger(tokenizedTime[0]) * 3600);
      absoluteValueTime += (int)(StringToInteger(tokenizedTime[1]) * 60);
      break;
    case    MMSS:
      absoluteValueTime = (int)(StringToInteger(tokenizedTime[0]) * 60);
      absoluteValueTime += (int)StringToInteger(tokenizedTime[1]);
      break;
    case    HH:
      absoluteValueTime = (int)(StringToInteger(tokenizedTime[0]) * 3600);
      break;
    case     MM:
      absoluteValueTime = (int)(StringToInteger(tokenizedTime[0]) * 60);
      break;
    case   SS:
      absoluteValueTime = (int)StringToInteger(tokenizedTime[0]);
      break;
    }
    return absoluteValueTime;
  }

  //+------------------------------------------------------------------+
  //|  Timestamp to string function                                    |
  //+------------------------------------------------------------------+
  string CUtils :: IntTimeToString (int time) {
    string timeOnString;
    int temp;

    temp = time / 3600;
    if(temp < 10)
      StringAdd(timeOnString, ("0" + IntegerToString(temp) + ":"));
    else
      StringAdd(timeOnString, (IntegerToString(temp) + ":"));
    time -= temp * 3600;

    temp = time / 60;
    if(temp < 10)
      StringAdd(timeOnString, ("0" + IntegerToString(temp) + ":"));
    else
      StringAdd(timeOnString, (IntegerToString(temp) + ":"));
    time -= temp * 60;

    if(time < 10)
      StringAdd(timeOnString, ("0" + IntegerToString(time)));
    else
      StringAdd(timeOnString, IntegerToString(time));

    return timeOnString;
  }
};

//+------------------------------------------------------------------+
//|  Candle size function                                            |
//+------------------------------------------------------------------+
double CUtils :: CandleSize (ENUM_TIMEFRAMES u_timeframe = PERIOD_CURRENT, 
                            int u_shift = 1) {
  return MathAbs(iOpen(_Symbol, u_timeframe, u_shift) - iClose(_Symbol, u_timeframe, u_shift));
}

//+------------------------------------------------------------------+
//| Is candle positive function                                      |
//+------------------------------------------------------------------+
bool CUtils :: IsCandlePositive (ENUM_TIMEFRAMES u_timeframe = PERIOD_CURRENT, 
                                int u_shift = 1) {
  return iOpen(_Symbol, u_timeframe, u_shift) < iClose(_Symbol, u_timeframe, u_shift);
}

//+------------------------------------------------------------------+
//| Is candle negative function                                      |
//+------------------------------------------------------------------+
bool CUtils :: IsCandleNegative (ENUM_TIMEFRAMES u_timeframe = PERIOD_CURRENT, 
                                int u_shift = 1) {
  return iOpen(_Symbol, u_timeframe, u_shift) > iClose(_Symbol, u_timeframe, u_shift);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|  Expert positions function                                       |
//+------------------------------------------------------------------+
void CUtils :: ExpertPositions (long magicNumber, 
                                ulong &dest_tickets[]) {
  ulong ticket;
  ArrayFree(dest_tickets);

  for(int i = 0; i < PositionsTotal(); i++) {
    ticket = PositionGetTicket(i);
    PositionSelectByTicket(ticket);
    if(PositionGetInteger(POSITION_MAGIC) == magicNumber)
      ArrayResize(dest_tickets, i + 1);
    dest_tickets[i] = ticket;
  }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CUtils :: ArrayShift(int ut_shift, 
                          double &ut_buffer[]) {
  if(ut_shift != 0) {
    ArraySetAsSeries(ut_buffer, true);
    for(int i = ut_shift; i < ArraySize(ut_buffer); i++)
      ut_buffer[i - ut_shift] = ut_buffer[i];
  }
}
//+------------------------------------------------------------------+
