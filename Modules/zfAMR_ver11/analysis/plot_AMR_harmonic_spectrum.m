function plot_AMR_harmonic_spectrum(results, key, fIdx, tIdx)
% Plot full harmonic spectrum for a given channel / field / temperature
%
% results : output of analyze_AMR_symmetry
% key     : internal key, e.g. 'ch2'
% fIdx    : field index
% tIdx    : temperature index

    out = results.(key).data(fIdx, tIdx);

    if isempty(out.n)
        warning('No spectrum available for this entry.');
        return
    end

    figure('Color','w');
    stem(out.n, out.Amp, 'filled','LineWidth',1.5);
    grid on;

    xlabel('Harmonic number n');
    ylabel('Amplitude');
    title(sprintf('Harmonic spectrum | %s', results.(key).tag));

    set(gca,'FontSize',14);
end
