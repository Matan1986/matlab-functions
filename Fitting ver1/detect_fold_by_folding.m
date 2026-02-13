function [bestFold, bestQ] = detect_fold_by_folding(theta, y, folds)

Qall = nan(size(folds));
for i = 1:numel(folds)
    Qall(i) = folding_quality(theta, y, folds(i), 1);
end

[bestQ,idx] = max(Qall);
bestFold = folds(idx);

figure('Color','w');
plot(folds, Qall, '-o','LineWidth',1.5);
xlabel('fold');
ylabel('Folding quality Q');
title('Fold detection');
grid on;
end
