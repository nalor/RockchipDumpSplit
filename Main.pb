EnableExplicit

XIncludeFile "Include_Console.pbi"
XIncludeFile "Include.pbi"

; History:
; 20140328 .. nalor .. erstellt
; 20140329 .. nalor .. Blockgröße in CopyFiles auf 1MB verändert
;                      0.3 erstellt
; 20140406 .. nalor .. Prüfung auf vorhandensein von USER verfeinert: muss mind. 1 Byte groß sein!
;                      0.4 erstellt
; 20140408 .. nalor .. Pfad zum Src war jetzt noch fix enthalten - korrigiert
;                      umbenannt auf RockchipBackupSplit
;                      0.5 erstellt
; 20140410 .. nalor .. noch einmal umbenannt auf 'RockchipExportSplit'
;                      gibt jetzt auch Größenangaben mit aus
;                      legt Parameter.txt jetzt erst an wenn man wirklich splittet
;                      0.6 erstellt
;                      jetzt werden noch ein paar statistik daten ausgegeben
;                      und falls das zielverzeichnis bereits vorhanden ist wird es nach bestätigung gelöscht
; 20140411 .. nalor .. 0.7 erstellt
; 20140412 .. nalor .. RockchipConfig Prozeduren erstellt und eingefügt
;                      Calculator eingebaut
; 20140413 .. nalor .. Console_ Prozeduren mit eingefügt
;                      RockchipConfig Prozeduren um UTF16 erweitert
;                      alles noch etwas verschönert :)
;                      es wird jetzt auf freien Speicherplatz geprüft
;                      wenn kein SrcFile angegeben ist wird gefragt ob man den Calculator starten möchte
;                      0.9 erstellt
; 20140414 .. nalor .. man kann jetzt auch ein Parameter-File als Parameter angeben, dann werden die Config Files entsprechend erstellt
;                      0.91 erstellt
; 20140415 .. nalor .. nur etwas Ordnung gemacht, Abbruch-Behandlung ist jetzt durchgängiger
;                      im Fehlerfall wird am Ende jetzt immer angehalten damit man die Meldung lesen kann
;                      BlockSize und ParamBlockCnt können jetzt aus Ini File eingelesen werden
;                      theoretisch eine Trimmfunktion mit eingefügt - Ersparnis ist aber fast 0 - deswegen nicht aktiviert
; 20140416 .. nalor .. ein bisschen Farbe mit eingefügt
;                      0.92 erstellt
; 20140427 .. nalor .. BUGFIX: wenn man eine Parameter Datei angegeben hat, aber keine IMG Files verfügbar waren, hat er am Ende einen Fehler vermutet (falscher Rückgabewert)
; 20140501 .. nalor .. alle RockChipConfig Prozeduren überarbeitet und vereinheitlicht
;                      man kann jetzt im Ini File auch eine gewünschte Reihenfolge für die ConfigFiles angeben
;                      0.93 erstellt
; 20140503 .. nalor .. GAPs werden jetzt erkannt und ausgegeben
;                      0.94 erstellt
; 20140504 .. nalor .. prüfung ob sich Partitionen überlappen (könnte passieren wenn man die parameter Datei manuell editiert)
;                      Suche nach INI File im Verzeichnis des SrcFiles, danach im Programmverzeichnis - und immer Ausgabe wenn etwas gefunden wurde
;                      0.95 erstellt
; 20140618 .. nalor .. Bugfix GAP Darstellung: wenn nach der vorletzten Partition ein GAP erkannt wurde, dann wurde der Gap-Wert für die letzte Partition nicht zurückgesetzt (weil für diese keine nachfolgende Partition mehr vorhanden ist)
;                      Prozedur 'CreateParamWithoutGaps' erstellt - wird von SplitImage und ParamCreateConfigFiles aufgerufen wenn man die Aktion dann durchführt
;                      >> erstellt Parameter-Files ohne GAPs falls welche vorhanden waren
;                      0.96 erstellt
; 20151001 .. nalor .. Bugfix: check if GetFreeSpace is successful or not included
;                      removed all included but unused procedures
;                      changed color of title line
;                      0.97 erstellt


; ToDo: misc.img dynamisch erstellen

#Title="RockchipDumpSplit 0.97"

;- Procedures
Define bEnableLog.b=#True
Define iBlockSize.i
Define iParamBlockCnt.i

Declare.i ParamFileToMem(sSrcFile.s, *Param, iBlockSize.i=512, iParamBlockCnt.i=2)

Procedure WriteLog(sText.s, bError.b=#False, bConsole.b=#True)
	Shared bEnableLog
	Protected iColor.i
	
	Debug sText
	
	If bConsole
		If bError
			iColor=ConsoleGetColor()
			ConsoleColor(12, 0)
		EndIf
		PrintN(sText)
		
		If bError
			ConsoleSetColor(iColor)
		EndIf
		
	EndIf
	
	If (bEnableLog Or bError )
		LogFileStd(sText)
	EndIf
		
EndProcedure

Procedure.l InMem(StartPos.l, *MainMem, MainLen.l, *FindMem, FindLen.l)
	Protected FoundPos.l, MainArrayLoop.l
	If StartPos < 1 : StartPos = 1 : EndIf
	FoundPos.l = 0
	For MainArrayLoop.l = StartPos - 1 To MainLen -1
		If MainArrayLoop + FindLen = MainLen
		;End reached
			Break
		EndIf
		If CompareMemory(*MainMem + MainArrayLoop, *FindMem, FindLen) = 1
			FoundPos = MainArrayLoop; + 1
			Break
		EndIf   
	Next
	ProcedureReturn FoundPos
EndProcedure


Procedure.l FindStringMem(*MainMem, StringToFind.s, StartPos.i=0)
	Protected MainMemSize.i
	Protected *FindMem
	Protected RetVal.l=-1
	
	MainMemSize=MemorySize(*MainMem)
	
	*FindMem=AllocateMemory(Len(StringToFind)+1)
	
	If *FindMem
		PokeS(*FindMem, StringToFind, -1, #PB_Ascii)
		
		RetVal=InMem(StartPos, *MainMem, MainMemSize, *FindMem, Len(StringToFind))
		
		FreeMemory(*FindMem)
	Else
		Debug "Error AllocateMem"
	EndIf
	
	ProcedureReturn RetVal
EndProcedure
	
Procedure.i Mem_FindEOL(*MainMem, StartPos.i=0)

	Protected iCnt.i
	Protected iMemSize.i
	Protected aTemp.a
	Protected iLineCnt.i
	Protected iLastLineChange.i=0
	
	iMemSize=MemorySize(*MainMem)
	iLineCnt=0
	For iCnt=StartPos To iMemSize-1 Step 1
		aTemp=PeekB(*MainMem+iCnt)
		If (aTemp=$0A) ; LineFeed erkannt
			ProcedureReturn iCnt
		ElseIf (aTemp=$0D)	;wenn carriage return erkannt wird
			If (iCnt<iMemSize) ;dann ist noch mind. 1 byte platz - wir können also das folgebyte noch analysieren
				aTemp=PeekB(*MainMem+iCnt+1)
				If (aTemp=$0A) ;wenn das Byte danach auch noch LF ist
					iCnt+1
				EndIf
				ProcedureReturn iCnt			
			EndIf
		EndIf
	Next
	
	ProcedureReturn -1
	
EndProcedure


#Block = 1024*1024 ; 1MB

Procedure.q GetTrimmedByteCnt(sSrcfile.s, qSrcStart.q, qSrcLen.q) 
	Protected iSrcFile.i
	Protected iDstFile.i
	
	Protected *Buffer
	Protected *CompBuffer
	Protected MaxBytes.l
	Protected qSrcPos.q=qSrcStart
	Protected iTmp.i
	
	Protected iRetVal.i=#True
	
	Protected qTrimBytes.q=0
	Protected iTrimBlocks.i=0
	
	Protected qResult.q=0
	
	Protected aByte.a
	
	*CompBuffer=AllocateMemory(#Block)
	If *CompBuffer
		For iTmp=0 To #Block-1
			PokeB(*CompBuffer+iTmp, $FF)
		Next
		
	Else
		WriteLog("ERROR!! allocating comp-buffer mem!", #True)
		iRetVal=#False		
	EndIf
	
	If iRetVal
		iSrcFile=ReadFile(#PB_Any, sSrcfile)
		If iSrcFile
			*Buffer = AllocateMemory(#Block)  ;Speicher 0 mit 4096 Bytes reservieren 
			If *Buffer
				
				qSrcPos=qSrcStart+qSrcLen
				While qSrcPos>qSrcStart  ;Wiederhole diese Schleife solange wir nicht am Start angekommen sind
					If qSrcPos-qSrcStart > #Block   ;wenn bis zur Startposition mehr als #Block 
						MaxBytes = #Block         ;Bytes betragen, dann begrenze das auf #Block Bytes
					Else                        ;ansonsten nimm den Rest. 
						MaxBytes = qSrcPos-qSrcStart
						Debug "nimm den Rest! >"+qSrcStart+"< >"+qSrcPos+"<"
					EndIf 
					qSrcPos-MaxBytes
					FileSeek(iSrcFile, qSrcPos) ; zur neuen Einleseposition gehen
; 					Debug "neue SrcPos >"+qSrcPos+"<"
					
					iTmp=ReadData(iSrcFile, *Buffer, MaxBytes)   ;Lese den nächsten Datenblock in der Datei in Puffer ein 
					If iTmp<>MaxBytes
						WriteLog("ERROR!! read bytes not identical requested byte count >"+MaxBytes+"< >"+iTmp+"<", #True)
						iRetVal=#False
						Break
					EndIf
					
					If CompareMemory(*Buffer, *CompBuffer, MaxBytes) ; wenn der Bereich komplett trimmbar ist
						qTrimBytes+MaxBytes
						iTrimBlocks+1
					Else
						Debug "wir haben den Block gefunden, der nicht mehr komplett trimmbar ist! MaxBytes >"+MaxBytes+"< Block >"+#Block+"< SrcPos >"+qSrcPos+"<"
						Debug "Komplett Trimbar waren >"+iTrimBlocks+"< Bytes >"+qTrimBytes+"<"
						For iTmp=MaxBytes-1 To 0 Step -1
							aByte=PeekA(*Buffer+iTmp)
							If aByte<>$FF
								Debug "byte is ungleich FF! >"+aByte+"<"
								
								qResult=qSrcPos+iTmp-qSrcStart
								Break 2
							EndIf
						Next
						
					EndIf
					
					

				Wend 
				
				FreeMemory(*Buffer)   ;Gib Speicher 0 wieder frei 
			Else
				WriteLog("ERROR!! allocating buffer mem!", #True)
				iRetVal=#False
			EndIf 
	
			CloseFile(iSrcFile)    ;Schließe Datei 0
		Else
			WriteLog("ERROR!! opening file >"+sSrcFile+"<", #True)
			iRetVal=#False
		EndIf 
	EndIf
	
	If *CompBuffer
		FreeMemory(*CompBuffer)
	EndIf
	
	If Not iRetVal
		qResult=-1
	EndIf
	
	ProcedureReturn qResult
EndProcedure

Procedure.i CopyFiles(sSrcfile.s, qSrcStart.q, qSrcLen.q, sDstFile.s) 
	Protected iSrcFile.i
	Protected iDstFile.i
	
	Protected *Buffer
	Protected MaxBytes.l
	Protected qSrcPos.q=qSrcStart
	Protected iTmp.i
	
	Protected iRetVal.i=#True
	
	iSrcFile=ReadFile(#PB_Any, sSrcfile)
	If iSrcFile
		iDstFile=CreateFile(#PB_Any, sDstFile)
		If iDstFile
			*Buffer = AllocateMemory(#Block)  ;Speicher 0 mit 4096 Bytes reservieren 
			If *Buffer
				FileSeek(iSrcFile, qSrcStart)
				While qSrcPos<qSrcStart+qSrcLen  ;Wiederhole diese Schleife solange nicht alles kopiert ist
					If Lof(iSrcFile) - Loc(iSrcFile) > #Block   ;Wenn die restlichen Bytes in der Datei mehr als #Block 
						MaxBytes = #Block         ;Bytes betragen, dann begrenze das auf #Block Bytes, 
					Else                        ;ansonsten nimm den Rest. 
						MaxBytes = Lof(iSrcFile) - Loc(iSrcFile) 
					EndIf 
					
					iTmp=ReadData(iSrcFile, *Buffer, MaxBytes)   ;Lese den nächsten Datenblock in der Datei in Puffer ein 
					If iTmp<>MaxBytes
						WriteLog("ERROR!! read bytes not identical requested byte count >"+MaxBytes+"< >"+iTmp+"<", #True)
						iRetVal=#False
						Break
					EndIf
					
					iTmp=WriteData(iDstFile, *Buffer, MaxBytes)   ;Schreibe gepufferte Bytes in die Datei
					If iTmp<>MaxBytes
						WriteLog("ERROR!! written bytes not identical requested byte count >"+MaxBytes+"< >"+iTmp+"<", #True)
						iRetVal=#False
						Break
					EndIf
					
					qSrcPos+MaxBytes
				Wend 
				
				FreeMemory(*Buffer)   ;Gib Speicher 0 wieder frei 
			Else
				WriteLog("ERROR!! allocating buffer mem!", #True)
				iRetVal=#False
			EndIf 
			CloseFile(iDstFile)    ;Schließe Datei 1
		Else
			WriteLog("ERROR!! creating destination file >"+sDstFile+"<", #True)
			iRetVal=#False
		EndIf 
		CloseFile(iSrcFile)    ;Schließe Datei 0
	Else
		WriteLog("ERROR!! opening file >"+sSrcFile+"<", #True)
		iRetVal=#False
	EndIf 
	
	ProcedureReturn iRetVal
EndProcedure 

Procedure.q GetFreeSpace(sVolumePathNames.s)
	; 20151001 .. nalor .. added check if successfull or not
	
	Protected qFreeBytesAvailable.q
	
	If Not GetDiskFreeSpaceEx_(sVolumePathNames,@qFreeBytesAvailable, #Null, #Null);
		qFreeBytesAvailable=-1
		WriteLog("ERROR! GetDiskFreeSpaceEx reported an error: >"+FormatMessage(GetLastError_())+"<", #True, #False)
	EndIf
	
	ProcedureReturn(qFreeBytesAvailable);
EndProcedure

Procedure.q GetPartSize(sLine.s, iBlockSize.i=512)
	
	Protected sTmp.s
	Protected qRetVal.q=0
	
	sTmp=StringField(sLine, 1, "@")
	sTmp=StringField(sTmp, 2, "x")
	qRetVal=Val("$"+sTmp)*iBlockSize
	
	ProcedureReturn qRetVal
	
EndProcedure

Procedure.s GetReadableSize(qSize.q, sUnit.s="", NbDecimal.i=2)
	
	Protected sTmp.s
	Protected iCnt.i
	Protected iTmp.i
	Protected dSize.d
	
	If sUnit=""
		If qSize>0
			iCnt=0
			While (qSize%1024)=0
				qSize=qSize/1024
				iCnt+1
			Wend
			
			sTmp=StrU(qSize, #PB_Quad)
		Else
			iCnt=-1
			sTmp=""
		EndIf
			
		Select iCnt
			Case 0
				sTmp+" B"
			Case 1
				sTmp+"KB"
			Case 2
				sTmp+"MB"
			Case 3
				sTmp+"GB"
			Case 4
				sTmp+"TB"
			Default
				sTmp+"??"
		EndSelect
	Else
		Select UCase(Trim(sUnit))
			Case "B"
				iCnt=0
			Case "KB"
				iCnt=1
			Case "MB"
				iCnt=2
			Case "GB"
				iCnt=3
			Case "TB"
				iCnt=4
			Default
				iCnt=0
		EndSelect		
		
		dSize=qSize
		For iTmp=1 To iCnt
			dSize=dSize/1024
		Next
		
		sTmp=StrD(dSize, NbDecimal)+sUnit
		
	EndIf
	
	
	ProcedureReturn sTmp
	
EndProcedure

Procedure.s GetReadableDuration(iMilliseconds.i, Seconds.i=#False)
	
	Protected sTmp.s
	Protected iCnt.i
	Protected iSec.i=0
	Protected iMin.i=0
	Protected iHour.i=0
	
	If iMilliseconds<1000 And Not Seconds
		sTmp=Str(iMilliseconds)+" milliseconds"
	Else
		If Seconds
			iSec=iMilliseconds
		Else
			iSec=iMilliseconds/1000
		EndIf
		
		While iSec>60
			iSec-60
			iMin+1
		Wend
		
		While iMin>60
			iMin-60
			iHour+1
		Wend
		
		If iHour>0
			sTmp=Str(iHour)+"h "+RSet(Str(iMin), 2, "0")+"m "+RSet(Str(iSec), 2, "0")+"s"
		ElseIf iMin>0
			sTmp=Str(iMin)+"m "+RSet(Str(iSec), 2, "0")+"s"
		Else
			sTmp=Str(iSec)+"s"
		EndIf
	EndIf

	ProcedureReturn sTmp
	
EndProcedure

Procedure.q GetPartStart(sLine.s, iBlockSize.i=512)
	
	Protected sTmp.s
	Protected qRetVal.q=0
	
	sTmp=StringField(sLine, 2, "@")
	sTmp=StringField(sTmp, 1, "(")
	sTmp=StringField(sTmp, 2, "x")
	qRetVal=Val("$"+sTmp)*iBlockSize
	
	ProcedureReturn qRetVal
	
EndProcedure

Procedure.s GetPartName(sLine.s)
	
	Protected sTmp.s
	Protected lRetVal.l=0
	
	sTmp=StringField(sLine, 2, "(")
	sTmp=Trim(sTmp, ")")
	
	ProcedureReturn sTmp
	
EndProcedure

Procedure.q DirectorySize(sDir.s)
	
	Protected qDirSize.q=0
	Protected iHdl.i
	
	qDirSize=FileSize(sDir)
	
	If qDirSize=-2
		qDirSize=0
		iHdl=ExamineDirectory(#PB_Any, sDir, "")
		If iHdl
			While NextDirectoryEntry(iHdl)
				If DirectoryEntryType(iHdl) = #PB_DirectoryEntry_File
					qDirSize+DirectoryEntrySize(iHdl)
				EndIf
			Wend
			FinishDirectory(iHdl)
		Else
			Debug "Error!!"
			qDirSize=-3
		EndIf
	ElseIf qDirSize>=0
		Debug "is a file!!"
		qDirSize=-4
	EndIf

	ProcedureReturn qDirSize
	
EndProcedure

Structure RockchipConfig_HeaderOffset
	Header_Size.i
	Date_Year.i
	Date_Month.i
	Date_Day.i
	Date_Hour.i
	Date_Minute.i
	Date_Second.i
	Date_Millisecond.i
	Block_Cnt.i
	Block_Start.i
	Block_Size.i
EndStructure

Structure RockchipConfig_Header
	Unicode.i
	Header_Size.i
	Date_Year.i
	Date_Month.i
	Date_Day.i
	Date_Hour.i
	Date_Minute.i
	Date_Second.i
	Date_Millisecond.i
	Block_Cnt.i
	Block_Start.i
	Block_Size.i
	Offset.RockchipConfig_HeaderOffset
EndStructure

Structure RockchipConfig_BlockOffset
	Block_Size.i
	Block_Name.i
	Block_File.i
	Block_Address.i
	Block_Active.i
EndStructure

Structure RockchipConfig_BlockMaxLen
	Block_Name.i
	Block_File.i
EndStructure

Structure RockchipConfig_Block
	Size.i
	Name.s
	File.s
	Address.l
	Active.i
	MaxLen.RockchipConfig_BlockMaxLen
	Offset.RockchipConfig_BlockOffset
EndStructure



Procedure RockchipConfig_GetHeaderOffset(*Header.RockchipConfig_Header, iUnicode.i=-1)
	If iUnicode=-1
		iUnicode=*Header\Unicode
	EndIf
	
	*Header\Offset\Header_Size=4	
	
	If iUnicode
			
		*Header\Block_Size=$0262
		*Header\Block_Start=$1D
		*Header\Header_Size=$1D
		
		*Header\Offset\Block_Cnt=22
		*Header\Offset\Block_Size=27
		*Header\Offset\Block_Start=23
		*Header\Offset\Date_Year=6
		*Header\Offset\Date_Month=8
		*Header\Offset\Date_Day=12
		*Header\Offset\Date_Hour=14
		*Header\Offset\Date_Minute=16
		*Header\Offset\Date_Second=18
		*Header\Offset\Date_Millisecond=20
	Else
		*Header\Block_Size=$0138
		*Header\Block_Start=$18
		*Header\Header_Size=$18
		
		*Header\Offset\Block_Cnt=$0D
		*Header\Offset\Block_Size=$14
		*Header\Offset\Block_Start=$10
		*Header\Offset\Date_Year=$06
		*Header\Offset\Date_Month=$08
		*Header\Offset\Date_Day=$09
		*Header\Offset\Date_Hour=$0A
		*Header\Offset\Date_Minute=$0B
		*Header\Offset\Date_Second=$0C
		*Header\Offset\Date_Millisecond=-1
		
	EndIf
	

EndProcedure



Procedure RockchipConfig_GetHeader(*Header.RockchipConfig_Header, sFilename.s)
	
	Protected iHdl.i
	Protected iRetVal.i=#True
	Protected iTmp.i
	Protected bTmp.b
	Protected aTmp.a
	
	If sFilename<>"" And FileSize(sFilename)>0 ; check if file is unicode or ascii
		iHdl=ReadFile(#PB_Any, sFilename)
		If iHdl
			*Header\Offset\Header_Size=4	; ist für ASCII und Unicode identisch
			FileSeek(iHdl, *Header\Offset\Header_Size)
			iTmp=ReadByte(iHdl)
			Select iTmp
				Case $18 ; ASCII
					Debug "ASCII Header detected"
					*Header\Unicode=#False
				Case $1D ; UNICODE
					Debug "Unicode Header detected"
					*Header\Unicode=#True
				Default
					WriteLog("ERROR!! Unknown Header detected! >"+iTmp+"<", #True)
					iRetVal=#False
			EndSelect
			
		Else
			WriteLog("ERROR!! couldn't read config file >"+sFilename+"<", #True)
			iRetVal=#False
		EndIf
	Else
		Debug "invalid file >"+sFilename+"<"
	EndIf	
	
	If iRetVal=#True
		RockchipConfig_GetHeaderOffset(*Header.RockchipConfig_Header)
	EndIf
	
	If iRetVal=#True
		If IsFile(iHdl)
			
			Debug *Header\Offset\Block_Cnt
			FileSeek(iHdl, *Header\Offset\Block_Cnt)
			*Header\Block_Cnt=ReadByte(iHdl)
			
			FileSeek(iHdl, *Header\Offset\Block_Size)
			*Header\Block_Size=ReadWord(iHdl)
			
			FileSeek(iHdl, *Header\Offset\Block_Start)
			*Header\Block_Start=ReadByte(iHdl)
			
			FileSeek(iHdl, *Header\Offset\Date_Year)
			*Header\Date_Year=ReadWord(iHdl)
			
			FileSeek(iHdl, *Header\Offset\Date_Month)
			*Header\Date_Month=ReadByte(iHdl)
			
			FileSeek(iHdl, *Header\Offset\Date_Day)
			*Header\Date_Day=ReadByte(iHdl)			
			
			FileSeek(iHdl, *Header\Offset\Date_Hour)
			*Header\Date_Hour=ReadByte(iHdl)			
			
			FileSeek(iHdl, *Header\Offset\Date_Minute)
			*Header\Date_Minute=ReadByte(iHdl)
			
			FileSeek(iHdl, *Header\Offset\Date_Second)
			*Header\Date_Second=ReadByte(iHdl)			
			
			If *Header\Offset\Date_Millisecond>0
				FileSeek(iHdl, *Header\Offset\Date_Millisecond)
				*Header\Date_Millisecond=ReadWord(iHdl)
			EndIf
			
		EndIf
		
	EndIf
	
	If IsFile(iHdl)
		CloseFile(iHdl)
	EndIf
	
; 	Debug "Header-Cnt >"+*RC_Header\Block_Cnt
	
	ProcedureReturn iRetVal
	
EndProcedure

Procedure RockchipConfig_SetHeader(*Header.RockchipConfig_Header, sFilename.s, iCreateNew.i=#False)
	
	Protected iRetVal.i=#True
	Protected iHdl.i
	Protected *HeaderNew
	Protected iDumpMode.i
	Protected iTmp.i
	
	If iCreateNew
		iDumpMode=0
	Else
		iDumpMode=2
	EndIf
	
	RockchipConfig_GetHeaderOffset(*Header)
	
	If iRetVal=#True And Not iCreateNew
		If FileSize(sFilename)<*Header\Header_Size
			iRetVal=#False
			WriteLog("ERROR!! RockchipConfig_SetHeader - file too small! >"+sFilename+"<", #True)
		EndIf
	EndIf
		
	If iRetVal=#True
	
		*HeaderNew=AllocateMemory(*Header\Header_Size)
		
		If *HeaderNew
			PokeS(*HeaderNew   , "CFG", 3, #PB_Ascii) ; Config Indicator
			PokeB(*HeaderNew+*Header\Offset\Header_Size, *Header\Header_Size)         ; HeaderSize
			
			PokeW(*HeaderNew+*Header\Offset\Date_Year  , Val(FormatDate("%yyyy", Date())))          ; YEAR
			PokeB(*HeaderNew+*Header\Offset\Date_Month , Val(FormatDate("%mm", Date())))            ; MONTH
			PokeB(*HeaderNew+*Header\Offset\Date_Day   , Val(FormatDate("%dd", Date())))            ; DAY
			PokeB(*HeaderNew+*Header\Offset\Date_Hour  , Val(FormatDate("%hh", Date())))            ; HOUR
			PokeB(*HeaderNew+*Header\Offset\Date_Minute, Val(FormatDate("%ii", Date())))            ; MINUTE
			PokeB(*HeaderNew+*Header\Offset\Date_Second, Val(FormatDate("%ss", Date())))            ; SECOND
			
			PokeB(*HeaderNew+*Header\Offset\Block_Start, *Header\Header_Size)              ; Start 1. Block
			
			PokeW(*HeaderNew+*Header\Offset\Block_Size  , *Header\Block_Size); BlockSize
			
			PokeB(*HeaderNew+*Header\Offset\Block_Cnt, *Header\Block_Cnt)              ; BlockCnt
			
		Else
			iRetVal=#False
			WriteLog("ERROR!! allocation memory to create RockchipConfig!", #True)
			
		EndIf
	EndIf
	
	If iRetVal=#True
		Debug PeekS(*HeaderNew, 3, #PB_Ascii)
		
		iTmp=Mem_Dump2File(*HeaderNew, sFilename, #False, iDumpMode, 0)
		
		If iTmp>0
			WriteLog("ERROR!! writing RockchipConfig to file >"+sFilename+"< Code >"+iTmp+"<")
			iRetVal=#False
		EndIf
		
		If *Header
			FreeMemory(*HeaderNew)
		EndIf		
		
	EndIf
	
	ProcedureReturn iRetVal
	
EndProcedure

Procedure RockchipConfig_Create(sFilename.s, iUnicode.i=#False)
	; wenn die Datei schon vorhanden ist wird sie einfach überschrieben!	
	Protected iRetVal.i=#True
	
	Protected Header.RockchipConfig_Header
	
	Header\Unicode=iUnicode
	
	iRetVal=RockchipConfig_SetHeader(@Header, sFilename, #True)

	ProcedureReturn iRetVal

EndProcedure

Procedure RockchipConfig_GetBlockOffset(*Block.RockchipConfig_Block, iUnicode.i)
	
	If iUnicode
		*Block\MaxLen\Block_Name=39
		*Block\MaxLen\Block_File=259
		
		*Block\Offset\Block_Size=0
		*Block\Offset\Block_Name=2
		*Block\Offset\Block_File=$52
		*Block\Offset\Block_Address=$25A
		*Block\Offset\Block_Active=$25E
		
	Else
		*Block\MaxLen\Block_Name=39
		*Block\MaxLen\Block_File=261
		
		*Block\Offset\Block_Size=0
		*Block\Offset\Block_Name=2
		*Block\Offset\Block_File=$2A
		*Block\Offset\Block_Address=$130
		*Block\Offset\Block_Active=$134			
		
	EndIf	
	

EndProcedure

Procedure RockchipConfig_GetBlock(*Block.RockchipConfig_Block, sFilename.s, iBlockNr.i)
	
	Protected iHdl.i
	Protected iRetVal.i=#True
	Protected iTmp.i
	Protected bTmp.b
	Protected aTmp.a
	Protected *BlockREAL
	
	Protected Header.RockchipConfig_Header
	Protected qBlockStart.q
	
	If FileSize(sFilename)<=0
		iRetVal=#False
		WriteLog("ERROR!! Configfile does not exist! >"+sFilename+"<", #True)
	EndIf	
	
	If Not RockchipConfig_GetHeader(@Header, sFilename)
		iRetVal=#False
		WriteLog("ERROR!! RockchipConfig_GetHeader failed!", #True)
	EndIf	
	
	If iRetVal=#True
		qBlockStart=Header\Block_Start+ Header\Block_Size * (iBlockNr-1)
		
		If FileSize(sFilename)<(qBlockStart+Header\Block_Size)
			WriteLog("ERROR!! File too small - there's no block "+iBlockNr, #True)
			iRetVal=#False
		EndIf
		
	EndIf
	
	If iRetVal=#True
		*BlockREAL=AllocateMemory(Header\Block_Size)
		
		If Not *BlockREAL
			WriteLog("ERROR!! allocating mem for block!", #True)
			iRetVal=#False
		EndIf
	EndIf
	
	If iRetVal=#True
		iHdl=ReadFile(#PB_Any, sFilename)
		If iHdl		
			FileSeek(iHdl, qBlockStart)
			
			iTmp=ReadData(iHdl, *BlockREAL, Header\Block_Size)
			
			If iTmp<>Header\Block_Size
				WriteLog("ERROR!! Reading data from file - read >"+iTmp+"< bytes but should be >"+Header\Block_Size+"<", #True)
				iRetVal=#False
			EndIf
			
			CloseFile(iHdl)
		Else
			WriteLog("ERROR!! opening file >"+sFilename+"<", #True)
			iRetVal=#False
		EndIf			
		
		
	EndIf
	
	If iRetVal=#True
		RockchipConfig_GetBlockOffset(*Block, Header\Unicode)
	EndIf			
	
	If iRetVal
		*Block\Size=PeekL(*BlockREAL+ *Block\Offset\Block_Size)
		
		If Header\Unicode
			*Block\Name=PeekS(*BlockREAL+ *Block\Offset\Block_Name, *Block\MaxLen\Block_Name, #PB_UTF16)
			*Block\File=PeekS(*BlockREAL+ *Block\Offset\Block_File, *Block\MaxLen\Block_File, #PB_UTF16)
		Else
			*Block\Name=PeekS(*BlockREAL+ *Block\Offset\Block_Name, *Block\MaxLen\Block_Name, #PB_Ascii)
			*Block\File=PeekS(*BlockREAL+ *Block\Offset\Block_File, *Block\MaxLen\Block_File, #PB_Ascii)
		EndIf
		
		*Block\Address=PeekL(*BlockREAL+ *Block\Offset\Block_Address)
		*Block\Active=PeekB(*BlockREAL+ *Block\Offset\Block_Active)
		                       
	EndIf
	
	If IsFile(iHdl)
		CloseFile(iHdl)
	EndIf
	
	ProcedureReturn iRetVal
	
EndProcedure

Procedure RockchipConfig_SetBlock(*Block.RockchipConfig_Block, sFilename.s, iBlockNr.i=-1, iNoFileCheck.i=#False)
	
	Protected iRetVal.i=#True
	Protected *BlockNew
	Protected iTmp.i
	Protected sTmp.s
	
	Protected iDumpMode.i
	
	Protected Header.RockchipConfig_Header
	Protected qBlockStart.q
	
	If FileSize(sFilename)<=0
		iRetVal=#False
		WriteLog("ERROR!! Configfile does not exist! >"+sFilename+"<", #True)
	EndIf	
	
	If Not RockchipConfig_GetHeader(@Header, sFilename)
		iRetVal=#False
		WriteLog("ERROR!! RockchipConfig_GetHeader failed!", #True)
	EndIf	
	
	If iRetVal=#True
		If iBlockNr=-1
			Debug "APPEND"
			iDumpMode=1 ; Append
		Else
			Debug "REPLACE"
			iDumpMode=2 ; Replace
			qBlockStart=Header\Block_Start+ Header\Block_Size * (iBlockNr-1)
			
			If FileSize(sFilename)<(qBlockStart+Header\Block_Size)
				WriteLog("ERROR!! File too small - there's no block "+iBlockNr, #True)
				iRetVal=#False
			EndIf
		EndIf
		
	EndIf	
	
	If iRetVal=#True
		RockchipConfig_GetBlockOffset(*Block, Header\Unicode)
	EndIf
	
	If iRetVal=#True
		If Len(*Block\Name)>*Block\MaxLen\Block_Name
			iRetVal=#False
			WriteLog("ERROR!! Blockname too long! Max len="+*Block\MaxLen\Block_Name+" >"+*Block\Name+"<", #True)
		EndIf
	EndIf
	
	If  Not iNoFileCheck
	
		If iRetVal=#True
			If Trim(*Block\File)<>""
				If  FileSize(*Block\File)<0
					iRetVal=#False
					WriteLog("ERROR!! Blockfile does not exist! >"+*Block\File+"<", #True)
				EndIf
			EndIf
		EndIf
		
		If iRetVal=#True
			If Not Header\Unicode ; nur wenn es ein ASCII Config ist
				If Trim(*Block\File)<>""
					If Not CheckPathAscii(*Block\File) ; in case there are special characters in the path
						sTmp=GetShortFileName(*Block\File)
						
						If Not CheckPathAscii(sTmp)
							iRetVal=#False				
							WriteLog("ERROR!! Couldn't get short-filename for >"+*Block\File+"< Result >"+sTmp+"<", #True)
						Else
							*Block\File=sTmp
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
		
		If iRetVal=#True
			If Len(*Block\File)>*Block\MaxLen\Block_File
				sTmp=GetShortFileName(*Block\File)
				
				If Len(sTmp)>*Block\MaxLen\Block_File
					iRetVal=#False
					WriteLog("ERROR!! Block-Filename too long! Max len="+*Block\MaxLen\Block_File+" >"+*Block\File+"< Short >"+sTmp+"<", #True)
				Else
					*Block\File=sTmp
				EndIf
			EndIf
		EndIf
	EndIf
	
	If iRetVal=#True
		*BlockNew=AllocateMemory(Header\Block_Size)
		
		If *BlockNew
			If Header\Unicode
				iTmp=#PB_UTF16	
			Else
				iTmp=#PB_Ascii
			EndIf
			
			
			PokeW(*BlockNew+*Block\Offset\Block_Size, Header\Block_Size)          ; BlockSize
		
			PokeS(*BlockNew+*Block\Offset\Block_Name, *Block\Name, -1, iTmp)  ;BlockName
			PokeS(*BlockNew+*Block\Offset\Block_File, *Block\File, -1, iTmp)  ;BlockFile
			
			PokeL(*BlockNew+*Block\Offset\Block_Address, *Block\Address)
			
			PokeB(*BlockNew+*Block\Offset\Block_Active, *Block\Active ); Active-Indicator
			
		Else
			iRetVal=#False
			WriteLog("ERROR!! allocation memory to add RockchipConfig block failed!", #True)
			
		EndIf
	EndIf
	
	If iRetVal=#True
		iTmp=Mem_Dump2File(*BlockNew, sFilename, #False, iDumpMode)
		
		If iTmp>0
			WriteLog("ERROR!! writing RockchipConfig block to file >"+sFilename+"< Code >"+iTmp+"<")
			iRetVal=#False
		EndIf
		
		If *Block
			FreeMemory(*BlockNew)
		EndIf			
		
	EndIf
	
	If iRetVal=#True
		Header\Block_Cnt+1
		If Not RockchipConfig_SetHeader(@Header, sFilename)
			iRetVal=#False
			WriteLog("ERROR!! Couldn't set new blockcnt in config-file! >"+sFilename+"< Cnt >"+iTmp+"<", #True)
		EndIf
	EndIf
		
	ProcedureReturn iRetVal
	
EndProcedure

Procedure ShowStartAndCount(qCount.q, iBlockSize.i=512)
	
	Protected sCount.s
	
	sCount="0x"+Hex(qCount, #PB_Quad)
	WriteLog("Start:"+RSet("0", 15, "."))
	WriteLog("Count:"+RSet(sCount, 15, ".")+"...(or decimal"+RSet(StrU(qCount, #PB_Quad), 13, ".")+")")
	PrintN("")
	; Geschwindigkeit ca. 512MB/Min >> 8,53MB/Sec >> 8947849Byte/sec
	
	Console_PrintCenter("Estimated duration to dump: "+GetReadableDuration( qCount*iBlockSize/8947849, #True), #True)	
	PrintN("")
	SetClipboardText(sCount)
	Console_PrintCenter("Copied COUNT to Clipboard - you can paste it into the input-field!", #True)
	PrintN("")
	
EndProcedure

Procedure ParamCalc(iBlockSize.i=512)
	
	Protected sTmp.s
	Protected iTmp.i
	Protected qFlashsize.q
	Protected iFlashcnt.i
	Protected sKeyPressed.s
	Protected qFullFlashCount.q
	Protected qFullFlashSize.q
	Protected iFirstRun.i
	
	Protected InputPos.COORD
	Protected NextPos.COORD
	
	Protected iColor.i
	
	PrintN("")
	
	Console_PrintCenter("Please press the button 'ReadFlashInfo' in the DumpTool", #True)
	Console_PrintCenter("and insert result-values as requested:", #True)
	PrintN("")
	
	qFlashsize=0
	iFirstRun=#True
	While qFlashsize=0
		If iFirstRun
			Print("Flash Size: ")
			Console_GetBufferLocation(@InputPos)
			PrintN("")
			PrintN("    (for example '4096MB')")
			Console_GetBufferLocation(@NextPos)
			iFirstRun=#False
		EndIf
		Console_SetBufferLocation(@InputPos)
		
		iColor=ConsoleGetColor()
		ConsoleColor(13, 0)
		sTmp=Console_GetString("1234567890BKMGT", 10)
		ConsoleSetColor(iColor)			
		
		
		
		iTmp=Val(sTmp)
		
		Select UCase(Right(sTmp, 2))
			Case "KB"
				qFlashsize=iTmp*1024
			Case "MB"
				qFlashsize=iTmp*Pow(1024, 2)
			Case "GB"
				qFlashsize=iTmp*Pow(1024, 3)
			Case "TB"
				qFlashsize=iTmp*Pow(1024, 4)
			Default
				Console_SetBufferLocation(@NextPos)
				iColor=ConsoleGetColor()
				ConsoleColor(12, 0)
				Console_PrintCenter("No unit detected! Please insert the value including the unit!")
				ConsoleSetColor(iColor)					
				
				Debug UCase(Right(sTmp, 2))
		EndSelect
		Debug qFlashsize
	Wend	
	
	Console_SetBufferLocation(@NextPos)
	Console_ClearLine()
	PrintN("")
	PrintN("")
	
	iFlashcnt=0
	iFirstRun=#True
	While iFlashcnt=0
		If iFirstRun
			Print("Number of Flash CS pages: ")
			Console_GetBufferLocation(@InputPos)
			PrintN("")
			PrintN("  (Example 'Flash CS: 0 1 2 3' means 4 pages >> insert '4')")
			PrintN("  (Example 'Flash CS: 0 2'     means 2 pages >> insert '2')")			
			Console_GetBufferLocation(@NextPos)
			iFirstRun=#False
		EndIf
		Console_SetBufferLocation(@InputPos)
		
		iColor=ConsoleGetColor()
		ConsoleColor(13, 0)
		sTmp=Console_GetString("1234567890", 2)
		ConsoleSetColor(iColor)		
		
		iFlashcnt=Val(Trim(sTmp))
		If iFlashcnt=0
			Console_SetBufferLocation(@NextPos)
			
			iColor=ConsoleGetColor()
			ConsoleColor(12, 0)
			Console_PrintCenter("Value cannot be 0 - please try again!")
			ConsoleSetColor(iColor)				
				
		EndIf
	Wend	
	
	Console_SetBufferLocation(@NextPos)
	Console_ClearLine()	
	PrintN("")
	PrintN("")
	
	qFullFlashSize=qFlashsize*iFlashcnt
	Console_PrintCenter("Detected Flashsize: "+GetReadableSize(qFlashsize)+" - FlashCS: >"+iFlashcnt+"< pages - FullSize "+GetReadableSize(qFullFlashSize), #True)
	qFullFlashCount=qFullFlashSize/iBlockSize
	Debug qFullFlashCount
	PrintN("")
	Console_PrintCenter("If you want a full dump insert the following values in the DumpTool:", #True)
	PrintN("")
	ShowStartAndCount(qFullFlashCount, iBlockSize)

	PrintN("")
	
EndProcedure

Procedure.s RemoveGapsFromCmdLine(sLine.s)
	
	Protected sNewLine.s
	Protected sPart.s
	Protected iPartCnt.i
	Protected iCnt.i
	Protected sTmp.s
	Protected sStart.s
	Protected sSize.s
	Protected sName.s
	Protected qCurStart.q=0
	Protected sFinalPart.s
	
	sPart=StringField( Right(sLine, Len(sLine)-FindString(sLine, "mtdparts=")-8)  , 2, ":")
	sNewLine=Left(sLine, Len(sLine)-Len(sPart)) ; damit hat man alles bis zum Doppelpunkt nach MTDPARTS mal in NewLine
	
	iPartCnt=CountString(sPart, ",")+1
	
	For iCnt=1 To iPartCnt
		sTmp=StringField(sPart, iCnt, ",")
		
		sSize=StringField(sTmp, 1, "@")
		sStart=StringField(StringField(sTmp, 2, "@"), 1, "(")
		sName=StringField(sTmp, 2, "(")
		
		If iCnt=1
			sFinalPart=sSize+"@"+sStart+"("+sName
			qCurStart=Val("$"+StringField(sStart, 2, "x"))+Val("$"+StringField(sSize, 2, "x"))
		Else
			sFinalPart=sSize+"@0x"+RSet(Hex(qCurStart, #PB_Quad), 8, "0")+"("+sName
			
			qCurStart+Val("$"+StringField(sSize, 2, "x"))
			
		EndIf
		
		Debug "FinalPart >"+iCnt+"< >"+sTmp+"< >"+sFinalPart
		
		If iCnt>1
			sNewLine+","
		EndIf
		
		sNewLine+sFinalPart
	Next
	
	ProcedureReturn sNewLine
	
EndProcedure

Procedure.i CreateParamWithoutGaps(sSrcFile.s, sDstFile.s="")
	
	Protected iSrcHdl.i
	Protected iDstHdl.i
	Protected iRetVal.i=#True
	
	Protected *Param
	Protected *Tmp
	Protected iParamSize.i
	Protected iTmp.i
	Protected iCnt.i
	Protected sLine.s
	
	If sDstFile=""
		sDstFile=GetPathPart(sSrcFile)+GetFilePart(sSrcFile, #PB_FileSystem_NoExtension)+"_GapsRemoved."+GetExtensionPart(sSrcFile)
	EndIf
	
	If iRetVal=#True
	
		; Parameter File ermitteln
		*Param=AllocateMemory(FileSize(sSrcFile))
		If Not *Param
			WriteLog("ERROR!! allocating memory (default)", #True)
			iRetVal=#False
		EndIf	
	EndIf
	
	If iRetVal=#True
		iSrcHdl=ReadFile(#PB_Any, sSrcFile)
			
		If Not iSrcHdl
			WriteLog("ERROR!! reading file >"+sSrcFile+"<")
			iRetVal=#False
		EndIf
	
	EndIf
	
	If iRetVal=#True
		
		iTmp=ReadData(iSrcHdl, *Param, Lof(iSrcHdl))
		
		If Not iTmp
			WriteLog("ERROR!! readdata of file >"+sSrcFile+"< failed!")
			iRetVal=#False
		EndIf
	EndIf
	
	If iSrcHdl
		CloseFile(iSrcHdl)
	
	EndIf
	
	If iRetVal
		iDstHdl=CreateFile(#PB_Any, sDstFile)
		
		If Not iDstHdl
			WriteLog("ERROR!!! (RemoveGapsFromParameter) couldn't create file >"+sDstFile+"< !")
			iRetVal=#False
		EndIf
	EndIf	
	
	If iRetVal=#True
		
		iParamSize=MemorySize(*Param)
		If iParamSize>0
			iRetVal=#False
		
			iTmp=Mem_GetLineCnt(*Param)
			
			For iCnt=1 To iTmp
				sLine=Mem_GetLine(*Param, iCnt)
				
				If Left(sLine, 7)="CMDLINE" ; gesuchte Zeile gefunden
					sLine=RemoveGapsFromCmdLine(sLine)
					iRetVal=#True
				EndIf
				; Zeile einfach ins DestFile schreiben
				WriteStringN(iDstHdl, sLine, #PB_Ascii)
							
			Next
				
			If Not iRetVal
				WriteLog("ERROR!! couldn't find important 'CMDLINE' line in parameter-file!", #True)
			EndIf
		Else
			WriteLog("ERROR!! memory too small!", #True)
			iRetVal=#False
		EndIf
	EndIf	
	
	If iRetVal=#True
		PrintN("")
		PrintN("Created a param file without gaps: "+sDstFile)
		PrintN("")
	EndIf
	
	
	If iDstHdl
		CloseFile(iDstHdl)
	EndIf
	
	ProcedureReturn iRetVal
	
EndProcedure


Procedure.i SplitImageFile(*ParamFile, sImageFile.s, iBlockSize.i=512, iParamBlockCnt.i=2, sNewOrder.s="")
	
	; 20151001 .. nalor .. in case GetFreeSpace reports an error a message is displayed with the option to carry on or abort
	
	; hat verschiedene Rückgabewerte:
	; 0 .. fehlgeschlagen (#false)
	; 1 .. alles in Ordnung (#true)
	; -1 .. wurde abgebrochen (vom Benutzer)
	
	Protected iFileHdl.i
	Protected sLine.s

	Protected sDstDir.s=GetPathPart(sImageFile)+GetFilePart(sImageFile, #PB_FileSystem_NoExtension)+"_Split\"
	Protected sConfigFileASC.s=sDstDir+GetFilePart(sImageFile, #PB_FileSystem_NoExtension)+"_ASCII.cfg"
	Protected sConfigFileUTF.s=sDstDir+GetFilePart(sImageFile, #PB_FileSystem_NoExtension)+"_UTF16.cfg"
	
	Protected iConfig_ASC.i=#True
	Protected iConfig_UTF.i=#True
	
	Protected sDstFile.s
	Protected iRetVal.i=#True
	Protected sKeyPressed.s
	
	Protected iParamSize.i
	
	Protected iTmp.i
	Protected iTmp2.i
	Protected sTmp.s
	Protected sTmp2.s
	Protected qTmp.q
	
	Protected iCnt.i
	
	Protected qFileSize.q=FileSize(sImageFile)
	
	Protected qPartStart.q
	Protected qPartSize.q
	Protected sPartName.s
	Protected sPartSize.s
	
	Protected qCopySize.q
	
	Protected qLatestPartStart.q
	
	Protected qSplitSize.q=0
	Protected iStartTime.i
	Protected iElapsedTime.i
	
	Protected fStatSec.f
	Protected fStatSize.f
	
	Protected bNotAllAvailable.b=#False
	Protected bNotFullAvailable.b=#False
	Protected iAvailableParts.i=0
	
	Protected qFreeDiskSpace.q
	
	Protected iTrimmedCopy.i=#False
	
	Protected iColor.i
	
	Protected Header.RockchipConfig_Header
	Dim Block.RockchipConfig_Block(0)
	Protected iBlockCnt.i=0
	Protected iBlockCur.i=1
	
	Dim sPartOrder.s(0)
	Protected iPartCnt.i
	Protected iPartChngCnt.i=0	
	
	Protected qPartGapSize.q=0
	Protected qCmplPartGapSize.q=0
	
	If qFileSize>0
		WriteLog("Filesize Imagefile: "+GetReadableSize(qFileSize))
	Else
		WriteLog("ERROR!! File too small >"+sImageFile+"< Size: "+GetReadableSize(qFileSize), #True)
		iRetVal=#False
	EndIf
	
	If iRetVal=#True
		
		iParamSize=MemorySize(*ParamFile)
		If iParamSize>0
			iRetVal=#False
			

			
			iTmp=Mem_GetLineCnt(*ParamFile)
			
			For iCnt=1 To iTmp
				sLine=Mem_GetLine(*ParamFile, iCnt)
				
				If Left(sLine, 7)="CMDLINE" ; gesuchte Zeile gefunden
					sLine=StringField(Right(sLine, Len(sLine)-FindString(sLine, "mtdparts=")-8), 2, ":")
					iRetVal=#True
					Break
				EndIf				
				
			Next
				
			If Not iRetVal
				WriteLog("ERROR!! couldn't find important 'CMDLINE' line in parameter-file!", #True)
			EndIf
		Else
			WriteLog("ERROR!! memory too small!", #True)
			iRetVal=#False
		EndIf
	EndIf
		
	If iRetVal=#True
		PrintN("")
		qLatestPartStart=0
		
		iBlockCnt=CountString(sLine, ",")+1
		
		For iTmp=1 To iBlockCnt
			sTmp=StringField(sLine, iTmp, ",")
						
			qPartStart=GetPartStart(sTmp)
			qPartSize=GetPartSize(sTmp)
			sPartSize=GetReadableSize(qPartSize)
			sPartName=GetPartName(sTmp)
			qPartGapSize=0
			
			Debug sTmp
			Debug qPartStart
			
			If iTmp<iBlockCnt
				sTmp2=StringField(sLine, iTmp+1, ",") ; die Daten der nächsten Partition ermitteln damit man auf eine GAP prüfen kann
				qPartGapSize=GetPartStart(sTmp2)-qPartStart-qPartSize
				
				If qPartGapSize>0
					Debug "GAP!! >"+sTmp2+"< qPartStart >"+qPartStart+"< qPartSize >"+qPartSize+"<"
				EndIf
				
				qCmplPartGapSize+qPartGapSize
			EndIf
			
			If qPartStart>qLatestPartStart
				qLatestPartStart=qPartStart
			EndIf
			
;  			WriteLog("PartStart >"+qPartStart+"< PartSize >"+qPartSize+"< FileSize >"+qFileSize+"< Name >"+sPartName+"<")

			sTmp=LSet("Part: "+sTmp, 40, ".")+RSet(sPartSize, 8, ".")+"..."
			bNotFullAvailable=#False
			
			If (qFileSize-qPartStart-qPartSize)>=0 ; wenn die partition komplett verfügbar ist
				If qPartSize>0 ; in case a known size is available
					qTmp=qPartSize
				Else
					qTmp=qFileSize-qPartStart
				EndIf
				
			ElseIf qFileSize-qPartStart>0 ; wenn die partition teilweise verfügbar ist
				qTmp=qFileSize-qPartStart
				bNotFullAvailable=#True
				
			Else
				qTmp=0 ; not available	
			EndIf
				
			If qTmp<=0 Or bNotFullAvailable
				If bNotFullAvailable
					sTmp2="NOT AVAILABLE(Size:"+RSet(GetReadableSize(qTmp), 8, " ")+")"
				Else
					sTmp2="NOT AVAILABLE!!!"
				EndIf
				bNotAllAvailable=#True
			Else
				sTmp2="available Size:"+RSet(GetReadableSize(qTmp), 8, " ")
				iAvailableParts+1
				
			EndIf
			
			If qPartGapSize>0
				sTmp2+" GAP"
			EndIf
			
			WriteLog(sTmp+sTmp2)
		Next
	EndIf
	
	If iRetVal=#True
		If FileSize(sImageFile)=iBlockSize*iParamBlockCnt
			
			PrintN("")
			
			Console_PrintCenter("The specified image file contains only the parameter-part.", #True)
			PrintN("")
			Console_PrintCenter("If you want to dump only the main partitions,", #True)			
			Console_PrintCenter("insert the following values in the DumpTool:", #True)
			PrintN("")
			ShowStartAndCount(qLatestPartStart/iBlockSize, iBlockSize)			
			PrintN("")
			Console_PrintCenter("and if you want to create a complete-dump just press RETURN", #True)
			Console_PrintCenter("to calculate the correct values!", #True)
			PrintN("")
			
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN for calculator or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)			
			
			
			Repeat
				sKeyPressed=Inkey()
				Delay(20)
			Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
			

			If sKeyPressed=Chr(27)
				Console_PrintCenter("Cancel now", #True)
				iRetVal=-1 ; Benutzerabbruch
			Else
				Console_PrintCenter("Start calculator", #True)
				ParamCalc(iBlockSize)
			EndIf

			PrintN("")			
			
			ProcedureReturn iRetVal ; damit nicht die restlichen Schritte irgendwie überlistet werden müssen
		EndIf
	EndIf
	
	If iRetVal=#True
		PrintN("")
		
		If iAvailableParts=0
			Console_PrintCenter("Nothing available!", #True)
			PrintN("")
			
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)				
			

		Else
			If qCmplPartGapSize>0
				PrintN("")
				WriteLog("Gaps between Partitions detected! "+GetReadableSize(qCmplPartGapSize)+" are lost because of those gaps!")
				PrintN("")
			EndIf		
			
			If bNotAllAvailable
				Console_PrintCenter("Not all parts available! Extract all available parts?", #True)
			Else
				Console_PrintCenter("All parts available! Continue?", #True)
			EndIf
			PrintN("")
			
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN to continue or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)			
			
		EndIf
		
		Repeat
			sKeyPressed=Inkey()
			Delay(20)
		Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
		
		If iAvailableParts=0
			Console_PrintCenter("Cancel now", #True)
			iRetVal=-1
		Else
			If sKeyPressed=Chr(27)
				Console_PrintCenter("Cancel now", #True)
				iRetVal=-1
			Else
				Console_PrintCenter("Continue now", #True)
; 				iTrimmedCopy=#True ; bringt irgendwie weniger als erwartet...
			EndIf
		EndIf
		PrintN("")
	EndIf
	
	If iRetVal=#True
		qTmp=DirectorySize(sDstDir)
		
		If qTmp<-1
			WriteLog("ERROR!! could not get directory size of destination directory >"+sDstDir+"< Value >"+Str(qTmp)+"<")
			iRetVal=#False
		ElseIf qTmp>0
			Console_PrintCenter("Destination directory is not empty!", #True)
			PrintN("")
			
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN to wipe directory completely or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)
			
			
			Repeat
				sKeyPressed=Inkey()
				Delay(20)
			Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
			
			If sKeyPressed=Chr(27)
				Console_PrintCenter("Cancel now", #True)
				iRetVal=-1
			Else
				Console_PrintCenter("Wipe directory now", #True)
				WriteLog("Wipe directory now", #False, #False)
				
				If Not DeleteDirectory(sDstDir, "", #PB_FileSystem_Recursive)
					WriteLog("ERROR!! wiping directory >"+sDstDir+"<", #True)
					iRetVal=#False
				Else
					iTmp=0
					While FileSize(sDstDir)=-2
						Debug "still here"
						Delay(50)
						iTmp+1
						
						If iTmp>100
							WriteLog("ERROR!! wiping directory failed strangely??", #True)
							iRetVal=#False
							Break
						EndIf
					Wend
					
					If iRetVal=#True
						Console_PrintCenter("Wipe successfull", #True)
					EndIf
				EndIf
				PrintN("")
			EndIf
		EndIf
	EndIf	
	
	If iRetVal=#True
		qFreeDiskSpace=GetFreeSpace(GetPathPart(sImageFile))
		sTmp=GetReadableSize(FileSize(sImageFile))

		If qFreeDiskSpace<0
			WriteLog("ERROR!! Couldn't determine free disk space - please make sure that at least "+sTmp+" are available!", #True)
			
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN to carry on or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)			
			
			
			Repeat
				sKeyPressed=Inkey()
				Delay(20)
			Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
			
			If sKeyPressed=Chr(27)
				Console_PrintCenter("Cancel now", #True)
				iRetVal=-1 ; Benutzerabbruch
			Else
				Console_PrintCenter("Carry on", #True)
			EndIf

			PrintN("")	
			
			
		ElseIf qFreeDiskSpace<FileSize(sImageFile)
			WriteLog("ERROR!! Not enough free disk space available! We need "+sTmp+" but only "+GetReadableSize(qFreeDiskSpace, Right(sTmp, 2))+" are available!", #True)
			iRetVal=#False
		EndIf
		
	EndIf
	
	If iRetVal=#True
		iStartTime=ElapsedMilliseconds()
	EndIf
	
	If iRetVal=#True
		If FileSize(sDstDir)<>-2 ; in case the destination dir does not exist
			If CreateDirectory_2(sDstDir)>0
				WriteLog("ERROR!! Error creating destination directory >"+sDstDir+"<")
				iRetVal=#False
			EndIf
		Else
			Debug "dstdir available!"
		EndIf
	EndIf
	

	If iRetVal=#True
		iBlockCnt+2 ; weil ja noch der dummy loader Eintrag und der parameter Eintrag dazu kommen
		ReDim Block(iBlockCnt)
		
		Block(iBlockCur)\Active=0
		Block(iBlockCur)\Address=0
		Block(iBlockCur)\File=""
		Block(iBlockCur)\Name="loader"
		iBlockCur+1

		sDstFile=sDstDir+"parameter.txt"
		iTmp=Mem_Dump2File(*ParamFile, sDstFile)
		
		If iTmp>0
			WriteLog("ERROR!! writing parameter-part to file >"+sDstFile+"< Code >"+iTmp+"<")
			iRetVal=#False
		Else
			
			Block(iBlockCur)\Active=1
			Block(iBlockCur)\Address=0
			Block(iBlockCur)\File=sDstFile
			Block(iBlockCur)\Name="parameter"			
			iBlockCur+1	
			
		EndIf
		
		If *ParamFile
			FreeMemory(*ParamFile)
		EndIf

		If qCmplPartGapSize>0 ; in case GAPS have been detected
			If Not CreateParamWithoutGaps(sDstFile)
				WriteLog("ERROR!!! during CreateParamWithoutGaps")
			EndIf
		EndIf
		
		
	EndIf
	
	If iRetVal=#True
		For iTmp=1 To CountString(sLine, ",")+1
			sTmp=StringField(sLine, iTmp, ",")
						
			qPartStart=GetPartStart(sTmp)
			qPartSize=GetPartSize(sTmp)
			sPartSize=GetReadableSize(qPartSize)
			sPartName=GetPartName(sTmp)
			
			sTmp=LSet("Part: "+sTmp, 40, ".")+RSet(sPartSize, 8, ".")+"..."
			
			If (qFileSize-qPartStart-qPartSize)>=0 ; wenn die partition komplett verfügbar ist
				If qPartSize>0 ; in case a known size is available
					qCopySize=qPartSize
				Else
					qCopySize=qFileSize-qPartStart
				EndIf
				
			Else
				qCopySize=0 ; not available	
			EndIf			
			
			If qCopySize<=0
				WriteLog(sTmp+"NOT AVAILABLE!!!")
				bNotAllAvailable=#True
			Else
				WriteLog(sTmp+"available Size:"+RSet(GetReadableSize(qCopySize), 8, " "))
				WriteLog("Start >"+qPartStart+"< Size >"+qCopySize+"< Name >"+sPartName+"<")

				sDstFile=sDstDir+sPartName+".img"
				
				If iTrimmedCopy
					qTmp=GetTrimmedByteCnt(sImageFile, qPartStart, qCopySize)
					If qTmp=-1
						WriteLog("ERROR!! GetTrimmedByteCnt failed!", #True)
						iRetVal=#False
						Break
					ElseIf qCopySize<>qTmp
						sTmp=GetReadableSize(qCopySize)
						WriteLog("trimmed split active! only "+GetReadableSize(qTmp, Right(sTmp, 2))+" of "+sTmp+" need to be copied!")
						qCopySize=qTmp
					EndIf
				EndIf
				
				If CopyFiles(sImageFile, qPartStart, qCopySize, sDstFile)
					WriteLog("Extract to >"+sDstFile+"< finished successfully!")
					
					qSplitSize+qCopySize
					
					Block(iBlockCur)\Active=1
					Block(iBlockCur)\Address=0
					Block(iBlockCur)\File=sDstFile
					Block(iBlockCur)\Name=sPartName			
					iBlockCur+1								
					
				Else
					WriteLog("ERROR!! extraction to >"+sDstFile+"< failed! Abort now!", #True)
					iRetVal=#False
					Break
				EndIf				
				PrintN("")
				
			EndIf
		Next		
		
	EndIf
	
	; hier werden die config files erzeugt:
	
	
	
	If iRetVal=#True And iBlockCnt>0 And Trim(sNewOrder)<>""
		
		iPartCnt=CountString(sNewOrder, ",")+1
		ReDim sPartOrder(iPartCnt)
		
		For iTmp=1 To iPartCnt
			sPartOrder(iTmp)=LCase(Trim(StringField(sNewOrder, iTmp, ",")))
		Next		
		
		For iTmp2=iPartCnt To 1 Step -1
			Debug "Suche >"+sPartOrder(iTmp2)+"< >"+iTmp2+"<"
			
			For iTmp=1 To iBlockCnt
				If LCase(Block(iTmp)\Name)=sPartOrder(iTmp2) And iTmp<>(iBlockCnt-iPartCnt+iTmp2); wenn der aktuelle Eintrag der aktuell gesuchte ist
					WriteLog("ReOrder partition block for config files >"+sPartOrder(iTmp2)+"<")
					Debug "tauschen! >"+Block(iTmp)\Name+"< >"+iTmp+"< >"+iTmp2+"<"
					Block(0)=Block(iTmp) ; den aktuellen Block mit dem letzten tauschen..
					Block(iTmp)=Block(iBlockCnt-iPartCnt+iTmp2)
					Block(iBlockCnt-iPartCnt+iTmp2)=Block(0)
					iPartChngCnt+1
				EndIf
			Next		
		Next		
	EndIf	
	
	
	If iRetVal=#True And iBlockCnt>0
		
		WriteLog("create config files")
		
		If Not RockchipConfig_Create(sConfigFileASC.s)
			iConfig_ASC=#False
			WriteLog("ERROR!! RockchipConfig_Create ASCII failed!", #True)
		EndIf
		
		If Not RockchipConfig_Create(sConfigFileUTF.s, #True)
			iConfig_UTF=#False
			WriteLog("ERROR!! RockchipConfig_Create UTF16 failed!", #True)
		EndIf
		
		For iTmp=1 To iBlockCnt
			If iConfig_ASC
				If Not RockchipConfig_SetBlock(@Block(iTmp), sConfigFileASC.s)
					iConfig_ASC=#False
					WriteLog("ERROR!! RockchipConfig_SetBlock ASC failed!", #True)
				EndIf
			EndIf
			
			If iConfig_UTF
				If Not RockchipConfig_SetBlock(@Block(iTmp), sConfigFileUTF.s)
					iConfig_UTF=#False
					WriteLog("ERROR!! RockchipConfig_SetBlock UTF failed!", #True)
				EndIf
			EndIf	
		Next
		PrintN("")
	EndIf	
	

	If Not iConfig_ASC And FileSize(sConfigFileASC)>=0
		DeleteFile(sConfigFileASC)
	EndIf
	
	If Not iConfig_UTF And FileSize(sConfigFileUTF)>=0
		DeleteFile(sConfigFileUTF)
	EndIf
	
	
	If iRetVal=#True
		iElapsedTime=ElapsedMilliseconds()-iStartTime
		
		WriteLog("Duration:     "+GetReadableDuration(iElapsedTime))
		WriteLog("Extracted size: "+GetReadableSize(qSplitSize))
		
		fStatSec=iElapsedTime/1000
		fStatSize=qSplitSize/1048576
		
		Debug "fStatSec >"+fStatSec
		Debug "fStatSize >"+fStatSize
		
		
		Console_PrintCenter("ExtractSpeed:   "+StrF( fStatSize/fStatSec, 2)+" MB/s", #True)
		PrintN("")
		
	EndIf		
	
	ProcedureReturn iRetVal		
	
EndProcedure

Procedure ConfigFile_CheckOrder(sFilename.s, sNewOrder.s)
	
	; Rückgabewerte:
	; 1 .. keine Änderung
	; 2 .. Änderung notwendig
	; 0 .. Fehler (#false)
	
	Protected iRetVal.i=1
	Protected iTmp.i
	Protected iTmp2.i
	
	Protected Header.RockchipConfig_Header
	Dim Block.RockchipConfig_Block(0)
	Dim sPartOrder.s(0)
	Protected iPartCnt.i
	
	If Not RockchipConfig_GetHeader(@Header, sFilename)
		iRetVal=#False
		WriteLog("ERROR!! RockchipConfig_GetHeader failed!", #True)
	EndIf	
	

	If iRetVal
		
		ReDim Block(Header\Block_Cnt)
		
		For iTmp=1 To Header\Block_Cnt
			If Not RockchipConfig_GetBlock(@Block(iTmp), sFilename, iTmp)
				WriteLog("ERROR!! couldn't get block >"+iTmp+"<", #True)
				iRetVal=#False
				Break
			EndIf
		Next
		
	EndIf
	
	If iRetVal
		
		iPartCnt=CountString(sNewOrder, ",")+1
		ReDim sPartOrder(iPartCnt)
		
		For iTmp=1 To iPartCnt
			sPartOrder(iTmp)=Trim(StringField(sNewOrder, iTmp, ","))
		Next		
		
		For iTmp2=iPartCnt To 1 Step -1
			Debug "Suche >"+sPartOrder(iTmp2)+"< >"+iTmp2+"<"
			
			For iTmp=1 To Header\Block_Cnt
				If Block(iTmp)\Name=sPartOrder(iTmp2) And iTmp<>(Header\Block_Cnt-iPartCnt+iTmp2) 
					; wenn der aktuelle Eintrag der aktuell gesuchte ist und dieser noch nicht da ist, wo er sein sollte
					iRetVal=2 ; reorder notwendig!
					Break
				EndIf
			Next		
		Next		
	EndIf
	
	ProcedureReturn iRetVal
	
EndProcedure

Procedure ConfigFile_ReOrder(sFilename.s, sNewOrder.s)
	
	Protected iRetVal.i=#True
	Protected iTmp.i
	Protected iTmp2.i
	
	Protected Header.RockchipConfig_Header
	Dim Block.RockchipConfig_Block(0)
	Dim sPartOrder.s(0)
	Protected iPartCnt.i
	Protected iPartChngCnt.i=0
	
	If Not RockchipConfig_GetHeader(@Header, sFilename)
		iRetVal=#False
		WriteLog("ERROR!! RockchipConfig_GetHeader failed!", #True)
	EndIf	

	If iRetVal=#True
		ReDim Block(Header\Block_Cnt)
		
		For iTmp=1 To Header\Block_Cnt
			If Not RockchipConfig_GetBlock(@Block(iTmp), sFilename, iTmp)
				WriteLog("ERROR!! couldn't get block >"+iTmp+"<", #True)
				iRetVal=#False
				Break
			EndIf
		Next
		
	EndIf
	
	If iRetVal=#True
		
		iPartCnt=CountString(sNewOrder, ",")+1
		ReDim sPartOrder(iPartCnt)
		
		For iTmp=1 To iPartCnt
			sPartOrder(iTmp)=Trim(StringField(sNewOrder, iTmp, ","))
		Next		
		
		For iTmp2=iPartCnt To 1 Step -1
			Debug "Suche >"+sPartOrder(iTmp2)+"< >"+iTmp2+"<"
			
			For iTmp=1 To Header\Block_Cnt
				If Block(iTmp)\Name=sPartOrder(iTmp2) And iTmp<>(Header\Block_Cnt-iPartCnt+iTmp2); wenn der aktuelle Eintrag der aktuell gesuchte ist
					Debug "tauschen! >"+Block(iTmp)\Name+"< >"+iTmp+"< >"+iTmp2+"<"
					Block(0)=Block(iTmp) ; den aktuellen Block mit dem letzten tauschen..
					Block(iTmp)=Block(Header\Block_Cnt-iPartCnt+iTmp2)
					Block(Header\Block_Cnt-iPartCnt+iTmp2)=Block(0)
					iPartChngCnt+1
				EndIf
			Next		
		Next		
	EndIf
	
	If iPartChngCnt>0
	
		If iRetVal=#True
			If Not RockchipConfig_Create(sFilename, Header\Unicode)
				iRetVal=#False
				WriteLog("ERROR!! ConfigFile Reorder failed!")
			EndIf
		EndIf
		
		If iRetVal=#True
			For iTmp=1 To Header\Block_Cnt
				If Not RockchipConfig_SetBlock(@Block(iTmp), sFilename, -1, #True)
					iRetVal=#False
					WriteLog("ERROR!! RockchipConfig_SetBlock failed!", #True)
					Break
				EndIf
			Next		
		EndIf
	EndIf
	
	ProcedureReturn iRetVal
	
EndProcedure

Procedure ParamShowConfigFile(sFilename.s, sParamOrder.s="")
	
	Protected iRetVal.i=#True
	Protected *Header
	Protected iTmp.i
	Protected iTmp2.i
	Protected sTmp.s
	
	Protected iDate.i
	
	Protected Header.RockchipConfig_Header
	Dim Block.RockchipConfig_Block(0)
	Dim sPartOrder.s(0)
	Protected iPartCnt.i
	
	Protected iColor.i
	Protected sKeyPressed.s
	
	Protected iAddressZero.i=0
	
	Protected iCnt.i
	
	If Not RockchipConfig_GetHeader(@Header, sFilename)
		iRetVal=#False
		WriteLog("ERROR!! RockchipConfig_GetHeader failed!", #True)
	EndIf	
	
	If iRetVal
		
		iDate=Date(Header\Date_Year, Header\Date_Month, Header\Date_Day, Header\Date_Hour, Header\Date_Minute, Header\Date_Second)
		
		PrintN("")
		WriteLog("Config-Details:")
		
		If Header\Unicode
			WriteLog("Format: UTF16", #False, #False)
			Print("Format: ")
			PrintNC("UTF16", 14)
			
			sTmp=" "+Str(Header\Date_Millisecond)+"mS"
		Else
			WriteLog("Format: ASCII", #False, #False)
			Print("Format: ")
			PrintNC("ASCII", 14)
			sTmp=""
		EndIf
		
		WriteLog("Date: "+FormatDateStd(iDate)+sTmp, #False, #False)
		Print("Date: ")
		PrintNC(FormatDateStd(iDate)+sTmp, 14)
		
		WriteLog("PartitionCount: "+Str(Header\Block_Cnt), #False, #False)
		Print("PartitionCount: ")
		PrintNC(Str(Header\Block_Cnt), 14)
		
		PrintN("")
	EndIf
	
	If iRetVal=#True
		
		ReDim Block(Header\Block_Cnt)
		
		For iCnt=1 To Header\Block_Cnt
			If Not RockchipConfig_GetBlock(@Block(iCnt), sFilename, iCnt)
				WriteLog("ERROR!! couldn't get block >"+iCnt+"<", #True)
				iRetVal=#False
				Break
			EndIf
		Next
		
		For iCnt=1 To Header\Block_Cnt
			WriteLog("Block >"+RSet(StrU(iCnt, #PB_Byte), 3, "0")+"< Name "+LSet(">"+Block(iCnt)\Name+"<", 15)+" Active >"+Block(iCnt)\Active+"<  Address >0x"+RSet(Hex(Block(iCnt)\Address, #PB_Long), 8, "0")+"<", #False, #False)
			
			Print("Block >")
			PrintC(RSet(StrU(iCnt, #PB_Byte), 3, "0"), 14)
			Print("< Name >")
			
			iTmp=Len(Block(iCnt)\Name)
			PrintC(Block(iCnt)\Name, 14)
			Print("<"+Space(15-iTmp)+" Active >")
			PrintC(Str(Block(iCnt)\Active), 14)
			Print("<  Address >")
			PrintC("0x"+RSet(Hex(Block(iCnt)\Address, #PB_Long), 8, "0"), 14)
			PrintN("<")
			
			
			WriteLog(" File >"+Block(iCnt)\File+"<", #False, #False)
			
			Print(" File >")
			PrintC(Block(iCnt)\File, 14)
			PrintN("<")
			
			PrintN("")
			
			If Block(iCnt)\Address=0
				iAddressZero+1
			EndIf
			
		Next
		
	EndIf
	
	If iRetVal=#True
	
		If sParamOrder<>"" And ConfigFile_CheckOrder(sFilename, sParamOrder)=2 ; wenn eine Paramfile übergeben wurde und eine neuordnung notwendig ist
			
			PrintN("")
			PrintN("")
			Console_PrintCenter("ReOrder of PartitionEntries requested - change it now?", #True)
			PrintN("")
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN to ReOrder or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)			
			
			Repeat
				sKeyPressed=Inkey()
				Delay(20)
			Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
			

			If sKeyPressed=Chr(27)
				Console_PrintCenter("Cancel now", #True)
				iRetVal=-1
			Else
				Console_PrintCenter("ReOrder now", #True)
				
				If Not ConfigFile_ReOrder(sFilename, sParamOrder)
					iRetVal=#False
					WriteLog("ERROR!! ConfigFile_ReOrder failed!!", #True)
				EndIf
			EndIf
		
		
			
		
		EndIf		
	EndIf
	
	ProcedureReturn iRetVal
	
EndProcedure

Procedure.i ParamCreateConfigFiles(sParamFile.s, iBlockSize.i=512, iParamBlockCnt.i=2, sNewOrder.s="")
	
	; 20151001 .. nalor .. check return value of GetFreeSpace
	
	; hat verschiedene Rückgabewerte:
	; 0 .. fehlgeschlagen (#false)
	; 1 .. alles in Ordnung (#true)
	; -1 .. wurde abgebrochen (vom Benutzer)
		
	
	Protected iFileHdl.i
	Protected sLine.s
	
	Protected *ParamFile
	
	Protected sDstDir.s=GetPathPart(sParamFile)
	Protected sConfigFileASC.s
	Protected sConfigFileUTF.s
	
	Protected iConfig_ASC.i=#True
	Protected iConfig_UTF.i=#True
	
	Protected sDstFile.s
	Protected iRetVal.i=#True
	Protected sKeyPressed.s

	Protected iParamSize.i=FileSize(sParamFile)

	Protected iTmp.i
	Protected iTmp2.i
	Protected sTmp.s
	Protected sTmp2.s
	Protected qTmp.q
	
	Protected iCnt.i

	Protected qPartStart.q
	Protected qPartSize.q
	Protected sPartName.s
	Protected sPartSize.s

	Protected iStartTime.i
	Protected iElapsedTime.i

	Protected bNotAllAvailable.b=#False
	Protected iAvailableParts.i=0
	
	Protected qFreeDiskSpace.q
	
	Protected iAvailable.i
	
	Protected iColor.i
	
	Dim Block.RockchipConfig_Block(0)
	Protected iBlockCnt.i=0
	Protected iBlockCur.i=1
	
	Dim sPartOrder.s(0)
	Protected iPartCnt.i
	Protected iPartChngCnt.i=0	
	
	Protected qPartGapSize.q=0
	Protected qCmplPartGapSize.q=0
	Protected iPartOverlapCnt.i=0
	
	If iParamSize>0 And iParamSize<iBlockSize*iParamBlockCnt
		WriteLog("Filesize Parameter-File: "+GetReadableSize(iParamSize))
	Else
		WriteLog("ERROR!! File has wrong size! >"+sParamFile+"< Size: "+GetReadableSize(iParamSize), #True)
		iRetVal=#False
	EndIf
	
	If iRetVal=#True
		sTmp=GetDirectoryName(sDstDir)
		If sTmp=""
			sTmp="RockchipConfig"
		Else
			If LCase(Right(sTmp, 6))="_split"
				sTmp=Left(sTmp, Len(sTmp)-6)
			EndIf
		EndIf
		
		sConfigFileASC=sDstDir+sTmp+"_ASCII.cfg"
		sConfigFileUTF=sDstDir+sTmp+"_UTF16.cfg"		
		
	EndIf
	
	If iRetVal=#True
		*ParamFile=AllocateMemory(iParamSize)
		If *ParamFile
			iFileHdl=ReadFile(#PB_Any, sParamFile)
			
			If iFileHdl
				iTmp=ReadData(iFileHdl, *ParamFile, iParamSize)
				If Not iTmp Or iTmp<>iParamSize
					WriteLog("ERROR!! ReadData failed! >"+iTmp+"< >"+iParamSize+"<", #True)
					iRetVal=#False
				EndIf
				CloseFile(iFileHdl)
			Else
				WriteLog("ERROR!! reading file >"+sParamFile+"<", #True)
				iRetVal=#False
			EndIf
		Else
			WriteLog("ERROR!! allocating memory", #True)
			iRetVal=#False
		EndIf		
	EndIf	
	
	If iRetVal=#True
		iRetVal=#False
		iTmp=Mem_GetLineCnt(*ParamFile)
		
		For iCnt=1 To iTmp
			sLine=Mem_GetLine(*ParamFile, iCnt)
			
			If Left(sLine, 7)="CMDLINE" ; gesuchte Zeile gefunden
				sLine=StringField(Right(sLine, Len(sLine)-FindString(sLine, "mtdparts=")-8), 2, ":")
				iRetVal=#True
				Break
			EndIf					
		Next
			
		If Not iRetVal
			WriteLog("ERROR!! couldn't find important 'CMDLINE' line in parameter-file!", #True)
		EndIf	
		
	EndIf
	
	If *ParamFile
		FreeMemory(*ParamFile)
	EndIf		
	
	If iRetVal=#True
		PrintN("")
		
		iBlockCnt=CountString(sLine, ",")+1
		
		For iTmp=1 To iBlockCnt
			sTmp=StringField(sLine, iTmp, ",")
						
			qPartStart=GetPartStart(sTmp)
			qPartSize=GetPartSize(sTmp)
			sPartSize=GetReadableSize(qPartSize)
			sPartName=GetPartName(sTmp)
			qPartGapSize=0
			Debug sTmp
			Debug qPartStart
			
			If iTmp<iBlockCnt
				sTmp2=StringField(sLine, iTmp+1, ",") ; die Daten der nächsten Partition ermitteln damit man auf eine GAP prüfen kann
				qPartGapSize=GetPartStart(sTmp2)-qPartStart-qPartSize
				qCmplPartGapSize+qPartGapSize
				
				If qPartGapSize<0
					iPartOverlapCnt+1
				EndIf
				
				If qPartGapSize>0
					Debug "GAP!! >"+sTmp2+"< qPartStart >"+qPartStart+"< qPartSize >"+qPartSize+"<"
				EndIf				
				
			EndIf			

;  			WriteLog("PartStart >"+qPartStart+"< PartSize >"+qPartSize+"< FileSize >"+qFileSize+"< Name >"+sPartName+"<")

			sTmp=LSet("Part: "+sTmp, 40, ".")+RSet(sPartSize, 8, ".")+"..."
			
			qTmp=FileSize(sDstDir+sPartName+".img")
				
			If qTmp<0		
				sTmp2="Not AVAILABLE!!!"
				bNotAllAvailable=#True
			Else
				sTmp2="available Size:"+RSet(GetReadableSize(qTmp), 8, " ")
				iAvailableParts+1
			EndIf
			
			If qPartGapSize>0
				sTmp2+" GAP"
			ElseIf qPartGapSize<0
				sTmp2+" OVL"
			EndIf
			
			WriteLog(sTmp+sTmp2)			
			
		Next
	EndIf
	
	If iRetVal=#True
		PrintN("")
		
		If qCmplPartGapSize>0
			PrintN("")
			WriteLog("Gaps between Partitions detected! "+GetReadableSize(qCmplPartGapSize)+" are lost because of those gaps!")
			PrintN("")
		EndIf
		
		If iPartOverlapCnt>0
			PrintN("")
			WriteLog("FATAL!! Partitions overlap detected! ", #True)
			PrintN("")
		EndIf
		
		If iAvailableParts=0
			Console_PrintCenter("No image files available!", #True)
			PrintN("")
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)			
			
			iRetVal=#False
		Else
			If bNotAllAvailable
				Console_PrintCenter("Not all image-files available! Create Config-Files for all available parts?", #True)
			Else
				Console_PrintCenter("All image-files available! Continue to create Config-Files?", #True)
			EndIf
			PrintN("")
			
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN to continue or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)				
			
		EndIf
		
		Repeat
			sKeyPressed=Inkey()
			Delay(20)
		Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
		
		If iRetVal=#True
			If sKeyPressed=Chr(27)
				Console_PrintCenter("Cancel now", #True)
				iRetVal=-1
			Else
				Console_PrintCenter("Continue now", #True)
			EndIf
		Else
			Console_PrintCenter("Cancel now", #True)
			iRetVal=-1
		EndIf
		PrintN("")
	EndIf

	
	If iRetVal=#True
		qFreeDiskSpace=GetFreeSpace(GetPathPart(sParamFile))
		
		If qFreeDiskSpace<0
			WriteLog("ERROR!! Couldn't determine free disk space - hopefully at least 1MB is available!", #True)
			
		ElseIf qFreeDiskSpace<Pow(1024, 2) ; es sollte mind. 1 MB frei sein
			WriteLog("ERROR!! Not enough free disk space available! Only "+GetReadableSize(qFreeDiskSpace)+" are available!", #True)
			iRetVal=#False
		EndIf
	EndIf
	
	If iRetVal=#True
		iStartTime=ElapsedMilliseconds()
	EndIf
	
	
	If iRetVal=#True
		iBlockCnt+2 ; weil noch die einträge für loader und parameter dazu kommen
		ReDim Block(iBlockCnt)
		
		Block(iBlockCur)\Active=0
		Block(iBlockCur)\Address=0
		Block(iBlockCur)\File=""
		Block(iBlockCur)\Name="loader"			
		iBlockCur+1	

		Block(iBlockCur)\Active=1
		Block(iBlockCur)\Address=0
		Block(iBlockCur)\File=sParamFile
		Block(iBlockCur)\Name="parameter"
		iBlockCur+1	
	
	EndIf
	
	If iRetVal=#True
		For iTmp=1 To CountString(sLine, ",")+1
			sTmp=StringField(sLine, iTmp, ",")
						
			qPartStart=GetPartStart(sTmp)
			qPartSize=GetPartSize(sTmp)
			sPartSize=GetReadableSize(qPartSize)
			sPartName=GetPartName(sTmp)
			
			sTmp=LSet("Part: "+sTmp, 40, ".")+RSet(sPartSize, 8, ".")+"..."
			
			sDstFile=sDstDir+sPartName+".img"
			
			If FileSize(sDstFile)<0		
				WriteLog(sTmp+"NOT AVAILABLE!!!")
				iAvailable=#False
			Else
				WriteLog(sTmp+"available - added to config!")
				iAvailableParts+1
				iAvailable=#True
			EndIf			
			
			If iAvailable
				Block(iBlockCur)\Active=1
				Block(iBlockCur)\Address=0
				Block(iBlockCur)\File=sDstFile
				Block(iBlockCur)\Name=sPartName
				iBlockCur+1						
			EndIf

		Next		
		
	EndIf
	
	; hier werden die config files erzeugt:
	
	
	
	If iRetVal=#True And iBlockCnt>0 And Trim(sNewOrder)<>""
		
		iPartCnt=CountString(sNewOrder, ",")+1
		ReDim sPartOrder(iPartCnt)
		
		For iTmp=1 To iPartCnt
			sPartOrder(iTmp)=LCase(Trim(StringField(sNewOrder, iTmp, ",")))
		Next		
		
		For iTmp2=iPartCnt To 1 Step -1
			Debug "Suche >"+sPartOrder(iTmp2)+"< >"+iTmp2+"<"
			
			For iTmp=1 To iBlockCnt
				If LCase(Block(iTmp)\Name)=sPartOrder(iTmp2) And iTmp<>(iBlockCnt-iPartCnt+iTmp2); wenn der aktuelle Eintrag der aktuell gesuchte ist
					WriteLog("ReOrder partition block for config files >"+sPartOrder(iTmp2)+"<")
					Debug "tauschen! >"+Block(iTmp)\Name+"< >"+iTmp+"< >"+iTmp2+"<"
					Block(0)=Block(iTmp) ; den aktuellen Block mit dem letzten tauschen..
					Block(iTmp)=Block(iBlockCnt-iPartCnt+iTmp2)
					Block(iBlockCnt-iPartCnt+iTmp2)=Block(0)
					iPartChngCnt+1
				EndIf
			Next		
		Next		
	EndIf	
	
	
	If iRetVal=#True And iBlockCnt>0
		
		WriteLog("create config files")
		
		If Not RockchipConfig_Create(sConfigFileASC.s)
			iConfig_ASC=#False
			WriteLog("ERROR!! RockchipConfig_Create ASCII failed!", #True)
		EndIf
		
		If Not RockchipConfig_Create(sConfigFileUTF.s, #True)
			iConfig_UTF=#False
			WriteLog("ERROR!! RockchipConfig_Create UTF16 failed!", #True)
		EndIf
		
		For iTmp=1 To iBlockCnt
			If iConfig_ASC
				If Not RockchipConfig_SetBlock(@Block(iTmp), sConfigFileASC.s)
					iConfig_ASC=#False
					WriteLog("ERROR!! RockchipConfig_SetBlock ASC failed!", #True)
				EndIf
			EndIf
			
			If iConfig_UTF
				If Not RockchipConfig_SetBlock(@Block(iTmp), sConfigFileUTF.s)
					iConfig_UTF=#False
					WriteLog("ERROR!! RockchipConfig_SetBlock UTF failed!", #True)
				EndIf
			EndIf	
		Next
		PrintN("")
	EndIf	
	
	If Not iConfig_ASC And FileSize(sConfigFileASC)>=0
		DeleteFile(sConfigFileASC)
	EndIf
	
	If Not iConfig_UTF And FileSize(sConfigFileUTF)>=0
		DeleteFile(sConfigFileUTF)
	EndIf
	
	If iRetVal=#True And qCmplPartGapSize>0 ; nur wenn GAPs erkannt wurden
		If Not CreateParamWithoutGaps(sParamFile)
			WriteLog("ERROR!! creating param file without gaps")
			iRetVal=#False
		EndIf
	EndIf
	
	
	If iRetVal=#True
		iElapsedTime=ElapsedMilliseconds()-iStartTime
		
		WriteLog("Duration:     "+GetReadableDuration(iElapsedTime))

		PrintN("")
		
	EndIf		
	
	ProcedureReturn iRetVal		
	
EndProcedure


Procedure.i ParamFileToMem(sSrcFile.s, *Param, iBlockSize.i=512, iParamBlockCnt.i=2)
	
	Protected iRetVal.i=#True
	Protected iSrcFile.i
	Protected *TempMem
	Protected iMemBytes.i=0
	Protected iCnt.i
	Protected iStart.i
	Protected iEnd.i
	Protected iTmp.i
	Protected iParamBlockSize.i=iBlockSize*iParamBlockCnt
	
	iSrcFile=ReadFile(#PB_Any, sSrcFile)
	If iSrcFile		
		*TempMem=AllocateMemory(iParamBlockSize)
		
		If Not *TempMem
			WriteLog("ERROR!! Allocating memory!")
			iRetVal=#False
		EndIf
		
		If iRetVal=#True
			iCnt=ReadData(iSrcFile, *TempMem, iParamBlockSize)
			If (iCnt<>1024)
				WriteLog("ERROR!! couldn't read the first "+iParamBlockSize+" bytes of file >"+sSrcFile+"< ReadSize >"+iCnt+"<", #True)
				iRetVal=#False
			EndIf
		EndIf
		
		If iRetVal=#True
			iStart=FindStringMem(*TempMem, "FIRMWARE")
			
			If iStart<0
				WriteLog("ERROR!! couldn't find beginning of parameter-part", #True)
				iRetVal=#False
			Else
				WriteLog("Parameter-StartPos: "+iStart, #False, #False)
			EndIf
		EndIf
		
		If iRetVal=#True
			iTmp=FindStringMem(*TempMem, "CMDLINE", iStart+8)
			If iTmp<0
				WriteLog("ERROR!! couldn't find beginning of last-line in parameter-part", #True)
				iRetVal=#False
			EndIf
		EndIf
			
		If iRetVal=#True
			iEnd=Mem_FindEOL(*TempMem, iTmp)
			
			If iEnd<0
				WriteLog("ERROR!! couldn't find end of parameter-part", #True)
				iRetVal=#False
			Else
				WriteLog("Parameter-EndPos: "+iEnd, #False, #False)
			EndIf
		EndIf			
			
		If iRetVal=#True
			iMemBytes=iEnd-iStart+1
			CopyMemory(*TempMem+iStart, *Param, iMemBytes)
			

		EndIf
			
		If *TempMem
			FreeMemory(*TempMem)
		EndIf
		
		CloseFile(iSrcFile)
	Else
		WriteLog("ERROR!! opening file >"+sSrcFile+"<")
		iRetVal=#False
	EndIf	
	
	If Not iRetVal
		ProcedureReturn 0
	Else
		ProcedureReturn iMemBytes
	EndIf
	
EndProcedure

Procedure.s GetFileString(sSrcFile.s, iCharCnt.i=3)
	
	Protected iSrcFile.i
	Protected sRetVal.s=""
	
	iSrcFile=ReadFile(#PB_Any, sSrcFile)
	If iSrcFile		
		
		sRetVal=ReadString(iSrcFile, #PB_Ascii, iCharCnt)
		
		CloseFile(iSrcFile)
	Else
		WriteLog("ERROR!! opening file >"+sSrcFile+"<")
	EndIf	
	
	ProcedureReturn sRetVal
	
EndProcedure

Define qTmp.q
Define sSrcFile.s
Define *Param
Define iParamSize.i
Define iRetVal.i=#True
Define *Tmp
Define iTmp.i
Define sTmp.s
Define sKeyPressed.s
Define iMode.i=0 ; default SplitMode, 1=ParameterFileMode

Define sIniFile.s
Define iConsoleOpen.i
Define iAskForKeypressAtEnd.i=#True
Define iColor.i
Define sConfig_ReOrder.s

;- main

OnErrorCall(@ErrorHandler())

iConsoleOpen=#False
If OpenConsole(#Title)
	iColor=ConsoleGetColor()
	ConsoleColor(2, 0)
	Console_PrintCenter(#Title, #True)
	ConsoleSetColor(iColor)

	PrintN("")
	WriteLog(#Title, #False, #False)
	iConsoleOpen=#True
Else
	WriteLog("ERROR!! couldn't open console", #True, #False)
	iRetVal=#False
EndIf

sSrcFile=""
If CountProgramParameters() ; wenn es Parameter gibt
	sSrcFile=ProgramParameter(0)
EndIf

CompilerIf #PB_Editor_CreateExecutable
	
CompilerElse

	sSrcFile="C:\testfile"

CompilerEndIf

sTmp=GetFilePart(ProgramFilename(), #PB_FileSystem_NoExtension)+".ini"

If FileSize(GetPathPart(sSrcFile)+sTmp)>0
	sIniFile=GetPathPart(sSrcFile)+sTmp
	WriteLog("INI File found in directory of the srcfile! >"+sIniFile+"<", #False, #False)
	Print("INI File found in directory of the srcfile! >")
	PrintC(sIniFile, 14)
	PrintN("<")
	
	PrintN("")
ElseIf FileSize(GetPathPart(ProgramFilename())+sTmp)>0
	sIniFile=GetPathPart(ProgramFilename())+sTmp
	WriteLog("INI File found in directory of the application! >"+sIniFile+"<", #False, #False)
	Print("INI File found in directory of the application! >")
	PrintC(sIniFile, 14)
	PrintN("<")	
	PrintN("")
Else
	sIniFile=""
EndIf

If iRetVal=#True
	iBlockSize=Val(ReadIniValue(sIniFile, "common", "blocksize", "512"))
	iParamBlockCnt=Val(ReadIniValue(sIniFile, "common", "paramblockcnt", "2"))
	sConfig_ReOrder=ReadIniValue(sIniFile, "configfile", "order", "")
EndIf


If iRetVal=#True
	If sSrcFile=""
		WriteLog("ERROR!! No SrcFile specified!", #True)
		iMode=2
	Else
		qTmp=FileSize(sSrcFile)
		
		If qTmp=-2
			WriteLog("ERROR!! File >"+sSrcFile+"< is a directory!", #True)
			iRetVal=#False
		ElseIf qTmp=-1
			WriteLog("ERROR!! File >"+sSrcFile+"< does not exist!", #True)
			iRetVal=#False
		ElseIf qTmp<300 ; wenn es kleiner als 300Byte ist, dann kann es ja noch nicht einmal eine Parameter Datei sein?? und auch keine configDatei
			WriteLog("ERROR!! Sourcefile is too small! Only "+GetReadableSize(qTmp), #True)
			iRetVal=#False
		Else
			; ermittle Art der Quelldatei
			sTmp=GetFileString(sSrcFile, 4)
			
			If Left(sTmp, 3)="CFG" ; es ist eine Config Datei!
				WriteLog("Source-ConfigFile: >"+sSrcFile+"<", #False, #False)
				Print("Source-ConfigFile: >")
				iMode=3
			ElseIf qTmp<(iParamBlockCnt*iBlockSize) ; wenn es weniger ist als in einem Parameter-Only Dump enthalten ist, dann ist es vermutlich nur ein einzelnes Parameter File
				WriteLog("Source-ParameterFile: >"+sSrcFile+"<", #False, #False)
				Print("Source-ParameterFile: >")
				iMode=1
			Else
				WriteLog("Source-Imagefile: >"+sSrcFile+"<", #False, #False)
				Print("Source-Imagefile: >")
				iMode=0
			EndIf
			
			PrintC(sSrcFile, 14)
			PrintN("<")
			PrintN("")
			
		EndIf
	EndIf
EndIf

If iRetVal=#True 
	Select iMode
			
		Case 1 ; ParameterMode
			iTmp=ParamCreateConfigFiles(sSrcFile, iBlockSize, iParamBlockCnt, sConfig_ReOrder)
			
			If iTmp=-1 ; wenn vom Benutzer abgebrochen wurde
				iAskForKeypressAtEnd=#False
			ElseIf Not iTmp
				WriteLog("ERROR!! ParamCreateConfigFiles failed!!", #True)
				iRetVal=#False
			EndIf			
			
		Case 2 ; CalculatorMode
			PrintN("")
			Console_PrintCenter("If you want to create a complete-dump just press RETURN", #True)
			Console_PrintCenter("to calculate the correct values!", #True)
			PrintN("")
			
			iColor=ConsoleGetColor()
			ConsoleColor(10, 0)
			Console_PrintCenter("Press RETURN for calculator or ESCAPE to cancel!", #True)
			ConsoleSetColor(iColor)
			
			Repeat
				sKeyPressed=Inkey()
				Delay(20)
			Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
			
	
			If sKeyPressed=Chr(27)
				Console_PrintCenter("Cancel now", #True)
				iAskForKeypressAtEnd=#False
			Else
				Console_PrintCenter("Start calculator", #True)
				ParamCalc(iBlockSize)
			EndIf
	
			PrintN("")			
			
		Case 3 ; ConfigFileMode
			iTmp=ParamShowConfigFile(sSrcFile, sConfig_ReOrder)
			
			If iTmp=-1 ; wenn vom Benutzer abgebrochen wurde
				iAskForKeypressAtEnd=#False
			ElseIf Not iTmp
				WriteLog("ERROR!! ParamShowConfigFile failed!!", #True)
				iRetVal=#False
			EndIf				
			
		Default ; SplitMode
			
			; Parameter File ermitteln
			*Param=AllocateMemory(iBlockSize*iParamBlockCnt)
			If *Param	
				iParamSize=ParamFileToMem(sSrcFile, *Param, iBlockSize, iParamBlockCnt)
				
				If iParamSize=0
					FreeMemory(*Param)
					iRetVal=#False
				Else
					*Tmp=ReAllocateMemory(*Param, iParamSize)
					
					If *Tmp
						*Param=*Tmp
						WriteLog("ParameterFile found!")
						PrintN("")
					Else
						WriteLog("ERROR!! Reallocating memory!")
						iRetVal=#False
					EndIf
					Debug iParamSize
				EndIf
			Else
				WriteLog("ERROR!! allocating memory (default)", #True)
				iRetVal=#False
			EndIf		
			
			If iRetVal=#True
				iTmp=SplitImageFile(*Param, sSrcFile, iBlockSize, iParamBlockCnt, sConfig_ReOrder)
				
				If iTmp=-1 ; wenn vom Benutzer abgebrochen wurde
					iAskForKeypressAtEnd=#False
				ElseIf Not iTmp
					WriteLog("ERROR!! SplitImageFile failed!!", #True)
					iRetVal=#False
				EndIf
			EndIf
	EndSelect
EndIf

If iConsoleOpen And iAskForKeypressAtEnd
	PrintN("")
	iColor=ConsoleGetColor()
	ConsoleColor(10, 0)
	Console_PrintCenter("Press RETURN or ESC to exit!", #True)
	ConsoleSetColor(iColor)	
	
	Repeat
		sKeyPressed=Inkey()
		Delay(20)
	Until sKeyPressed=Chr(27) Or sKeyPressed=Chr(13)
	
EndIf

If iConsoleOpen
	CloseConsole()
EndIf



; IDE Options = PureBasic 5.42 LTS (Windows - x86)
; CursorPosition = 2796
; FirstLine = 2893
; Folding = ------
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser
; EnableCompileCount = 0
; EnableBuildCount = 0
; EnableExeConstant