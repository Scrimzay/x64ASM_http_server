this is a simple http server in x64 asm cause asm is badass, i basically saw this guys video which was done in arm asm (https://github.com/dmtrKovalenko/macos-assembly-http-server) and wanted to convert it to x64 asm.
admittedly im not that good in x64 asm yet and dont know the x86/32 windows api functions so i used some chatgpt to help me build this. i put the C program to find the htons conversion for whatever ports at the bottom cause why not.
anyways this is really cool and im prob gonna make more x64 asm http servers cause i want to. and for anyone wondering, test.asm is just a basic minimal http server that i used for error testing since the port originally wasnt mapped correctly in main.asm.

if you want to run this, the build instructs are as follows (this is x64 asm so only x64 architechture non-mac hardware [does anyone still use 32bit/x86 stuff still?]):

nasm -f win64 main.asm -o main.obj (NASM required, and win64 must be declared to let NASM know its an x64 asm program, win32 would be x86)

gcc main.obj -o main -lws2_32 (GCC required and were using -lws2_32 flag since its required to use the windows socket apis/imports)

.\main , simple as
