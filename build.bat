@echo off

dmd -betterC -checkaction=halt -debug -g -mcpu=native -od=build -of=build/dadvent.exe -vcolumns -w ^
    -boundscheck=on -check=assert=on -check=bounds=on -check=in=on -check=invariant=on -check=out=on -check=switch=on ^
    -Isource -L=/incremental:no ^
    source/dadvent_windows.d source/dadvent_d3d11.d source/dadvent.d source/input.d

echo done