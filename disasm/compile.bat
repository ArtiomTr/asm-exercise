tasm /t .\data\Pvz0com.asm
tlink /t Pvz0Com

tasm /zi /t disasm
tasm /zi /t .\lib\filename
tasm /zi /t .\lib\string
tasm /zi /t .\lib\dis
tlink /v disasm filename string dis