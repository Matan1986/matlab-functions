function y = fourier_model(p, th, fold, Nh)

y = p(1);
k = 2;

for n = 1:Nh
    y = y + p(k)   * cos(n*fold*th) ...
          + p(k+1) * sin(n*fold*th);
    k = k + 2;
end
end
