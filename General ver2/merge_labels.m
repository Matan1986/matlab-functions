function outPC = merge_labels(plotChannels, labels)
    % keep original booleans and add .labels (LaTeX strings)
    outPC = plotChannels;
    outPC.labels = labels;
end