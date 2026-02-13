function depMode = detect_switching_dep_mode(parentDir)
    d = dir(parentDir);
    sub = d([d.isdir] & ~startsWith({d.name}, '.'));

    names = string({sub.name});

    if any(startsWith(names, "Temp Dep")) && numel(names) > 1
        depMode = "AmpTempGrid";
    else
        depMode = "SingleDep";
    end
end
