function out = switchingRowRmse(y, yhat)
%SWITCHINGROWRMSE Row-wise RMSE for 2D matrices.

r = y - yhat;
out = sqrt(mean(r.^2, 2, 'omitnan'));
end
