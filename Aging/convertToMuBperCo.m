function [noPause_M, pauseRuns] = convertToMuBperCo(noPause_M, pauseRuns)

x_Co = 1/3;
m_mol = 58.9332/3 + 180.948 + 2*32.066; % g/mol
muB = 9.274e-21;  % emu
NA  = 6.022e23;

convFactor = m_mol / (NA * muB * x_Co);

noPause_M = noPause_M * convFactor;
for i = 1:numel(pauseRuns)
    pauseRuns(i).M = pauseRuns(i).M * convFactor;
end
end
