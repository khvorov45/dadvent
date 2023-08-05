@echo off

fxc /nologo /T vs_5_0 /E vs /Od /Zi /WX /Ges /Fh source/shader_vs.c /Vn globalCompiledShader_shader_vs source/shader.hlsl 
fxc /nologo /T ps_5_0 /E ps /Od /Zi /WX /Ges /Fh source/shader_ps.c /Vn globalCompiledShader_shader_ps source/shader.hlsl 

@REM NOTE(khvorov) BYTE=char is to get shader binaries to compile with importC
dmd -P=-DBYTE=char -betterC -checkaction=halt -debug -g -mcpu=native -od=build -of=build/dadvent.exe -vcolumns -w ^
    -boundscheck=on -check=assert=on -check=bounds=on -check=in=on -check=invariant=on -check=out=on -check=switch=on ^
    -Isource -L=/incremental:no ^
    source/dadvent_windows.d source/dadvent_d3d11.d source/dadvent.d source/input.d source/shader_vs.c source/shader_ps.c source/font.c source/microui.c

echo done