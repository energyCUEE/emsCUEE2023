function [profit,expense,revenue] = GetExpense(Pnet,Buy_rate,Sell_rate,Resolution)
 expense = min(0,Pnet).*Buy_rate*Resolution ; % (minus sign)
 revenue = max(0,Pnet).*Sell_rate*Resolution ; % positive sign
 profit = revenue + expense ; 
end