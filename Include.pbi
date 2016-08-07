
CompilerIf Defined(FormatMessage, #PB_Procedure) = #False

  Procedure.s FormatMessage(ErrorNumber.l)

    Protected *Buffer, len, result.s
   
    len = FormatMessage_(#FORMAT_MESSAGE_ALLOCATE_BUFFER|#FORMAT_MESSAGE_FROM_SYSTEM,0,ErrorNumber,0,@*Buffer,0,0)
    If len
      result = PeekS(*Buffer, len - 2)
      LocalFree_(*Buffer)
      ProcedureReturn result
    Else
      ProcedureReturn "Errorcode: " + Hex(ErrorNumber)
    EndIf
   
  EndProcedure

CompilerEndIf



Procedure.i CheckDirectory(sPath.s)
; prüft ob Pfad in sPath theoretisch ein gültiges Verzeichnis ist - prüft aber nicht ob es existiert bzw. das Laufwerk vorhanden ist!	
	Protected iReturn.i
	
	If CreateRegularExpression(0, "^([a-zA-Z]:\\)([^/\\:*?"+Chr(34)+"<>|]+\\)*$")
		; Erklärung zur RegEx:
		; ^ ... StringAnfang
		; ([a-zA-Z]:\\) ... beginnt mit a-zA-Z und danach ein : und ein \
		; ( ... nächster Bereich
		; [^/\\:*?"+Chr(34)+"<>|] ... alles erlaubt bis auf (umkehrung wird durch ^ eingeleitet) / \ : * ? " < > |
		; + ... von den erlaubten 1 oder mehrere
		; \\ ... gefolgt von einem abschliessenden \
		; ) ... bereichsende
		; * ... und dieser bereich dann 0 mal oder öfter
		; $ ... stringende
		iReturn=MatchRegularExpression(0, sPath)
		FreeRegularExpression(0)
	Else
		iReturn=#False
		Debug RegularExpressionError()
	EndIf
	
	ProcedureReturn iReturn
	
EndProcedure

Procedure.i CreateDirectory_2(sDirName.s)
;# erzeugt alle notwendigen unterverzeichnisse nacheinander
;# 20110824 ... Prüfung auf gültiges Verzeichnis mit CheckDirectory eingefügt
;# 20120508 ... prüft ob Verzeichnis schon existiert - und nur wenn nicht werden alle entsprechendne Unterverzeichnisse erstellt
;#
;# Fehler: 0 .... Verzeichnis existiert bereits bzw. erfolgreich erstellt
;#         1 .... Laufwerk nicht gefunden
;#         2 .... Verzeichnis konnte nicht erstellt werden
;#         3 .... Verzeichnispfad nicht gültig

	Protected iResult.i=0
	Protected sPathPart.s=""
	Protected sPathPart2.s=""
	Protected iHelp.i=1
	Protected iError.i=0
	
;	LogFile("CreateDirectory_2 startet - Verzeichnis >"+sDirName+"<")

	If (CheckDirectory(sDirName))

		If (FileSize(sDirName)<>-2) ;Verzeichnis existiert nicht

			For iHelp=1 To 255 Step 1
		;		Debug "##################"
				sPathPart2=StringField(sDirName, iHelp, "\")
				If (sPathPart2="") ; wenn es keinen weiteren Teil mehr gibt wird abgebrochen
					Break
				EndIf
				
				If (iHelp>1)
					sPathPart=sPathPart+"\"+sPathPart2
				Else
					sPathPart=sPathPart2
				EndIf	
				
	;			Debug iHelp
	;			Debug sPathPart
				
				If (FileSize(sPathPart)<>-2) ;Verzeichnis existiert nicht
					If (iHelp=1)
		;				LogFile("Laufwerk nicht gefunden >"+sPathPart+"< - Abbruch")
						iError=1
						Break
					EndIf
						
					Debug "Verzeichnis existiert nicht >"+sPathPart+"< >> wird erstellt"
					iResult=CreateDirectory(sPathPart)
					Debug iResult
					
					If (iResult=0)
		;				LogFile("Verzeichnis konnte nicht erstellt werden - Abbruch >"+sPathPart+"<")
						iError=2
						Break
					EndIf
				EndIf
					
			Next
		EndIf
	Else
		iError=3
		Debug "Verzeichnis >"+sDirName+"< ist nicht gültig"
			
	EndIf	
;	LogFile("CreateDirectory_2 endet")
	ProcedureReturn iError

EndProcedure




Procedure.i LogFileStd(sData.s, sFilename.s="", sLogDir.s="")
	;# Parameter eingefügt damit man auch spezielle Logfiles schreiben kann (sFilename)
	;# 20110824 ... Parameter sLogDir eingefügt, mit dem angegeben kann wohin das Logfile geschrieben werden soll
	;#              Wenn der Parameter nicht angegeben ist, wird das Logdir im Unterverzeichnis "log" des aktuellen Programmverzeichnisses geschrieben

	Protected sLogDir_P.s
	Protected sLogFile_P.s
	Protected iFileHandle.i
	Protected iReturn.i=#True
	
	If (sLogDir="")
		sLogDir=GetPathPart(ProgramFilename())+"log\"
	EndIf
	
	If (CheckDirectory(sLogDir))
		sLogDir_P=sLogDir
	Else
		If (CheckDirectory(GetPathPart(ProgramFilename())+sLogDir))
			sLogDir_P=GetPathPart(ProgramFilename())+sLogDir
		Else
			Debug "CheckDir fehlgeschlagen"
			iReturn=#False
		EndIf
	EndIf
	
	If (iReturn)
		If (CreateDirectory_2(sLogDir_P)>0)
			Debug "Fehler Verzeichnis erzeugen"
			iReturn=#False
		EndIf
	EndIf
	
	If (iReturn)
		If sFilename=""
			sFilename="_"+ReplaceString(GetFilePart(ProgramFilename()), "."+GetExtensionPart(ProgramFilename()), "")
		EndIf
			
		sLogFile_P=sLogDir_P+FormatDate("%yyyy-%mm-%dd", Date())+sFilename+".txt"
		
		iFileHandle=OpenFile(#PB_Any,sLogFile_P)
		If iFileHandle
			FileSeek(iFileHandle, Lof(iFileHandle))         ; springt an das Ende der Datei (das Ergebnis von Lof() wird hierfür verwendet)
			WriteStringN(iFileHandle, FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss # "+Str(ElapsedMilliseconds())+" # ", Date())+sData)
			CloseFile(iFileHandle)
		Else
			Debug ("Datei konnte nicht geöffnet werden 01")
			iReturn=#False
		EndIf
	EndIf
	
	ProcedureReturn iReturn
EndProcedure


Procedure.s GetShortFileName ( Long.s )
	Protected Short.s = "\\?\"+Long
	GetShortPathName_ ( @Long, @Short, Len(Short) )
	ProcedureReturn Short
EndProcedure


Procedure.i CheckPathAscii(sPath.s)
; prüft ob Pfad in sPath theoretisch ein gültiges Verzeichnis ist - prüft aber nicht ob es existiert bzw. das Laufwerk vorhanden ist!	
	Protected iReturn.i
	
	If CreateRegularExpression(0, "^([a-zA-Z]:\\)([\x20-\x7E^/\\:*?"+Chr(34)+"<>|]+\\)*([\x20-\x7E^/\\:*?"+Chr(34)+"<>|])*$")
		; Erklärung zur RegEx:
		; ^ ... StringAnfang
		; ([a-zA-Z]:\\) ... beginnt mit a-zA-Z und danach ein : und ein \
		; ( ... nächster Bereich VERZEICHNISSE
		; [a-zA-Z0-9] ... nur ASCII erlaubt bis auf (umkehrung wird durch ^ eingeleitet) / \ : * ? " < > |
		; + ... von den erlaubten 1 oder mehrere
		; \\ ... gefolgt von einem abschliessenden \
		; ) ... bereichsende
		; * ... und dieser bereich dann 0 mal oder öfter		
		; ( ... nächster Bereich DATEI
		; [a-zA-Z0-9] ... nur ASCII erlaubt bis auf (umkehrung wird durch ^ eingeleitet) / \ : * ? " < > |
		; + ... von den erlaubten 1 oder mehrere
		; \\ ... gefolgt von einem abschliessenden \
		; ) ... bereichsende		
		; * ... und dieser bereich dann 0 mal oder öfter
		; $ ... stringende
		iReturn=MatchRegularExpression(0, sPath)
		FreeRegularExpression(0)
	Else
		iReturn=#False
		Debug RegularExpressionError()
	EndIf
	
	ProcedureReturn iReturn
	
EndProcedure





;- Memory Funktionen


Procedure.i Mem_Dump2File(*StartAddr, sFilename.s, iLen.i=#False, iMode.i=0, qDstAddr.q=0)
	; 20120508...FIR...Notwendige Verzeichnisse werden jetzt automatisch erstellt
	; 20140412...FIR...jetzt auch mit Append möglich
	; 20140430...FIR...jetzt mit Parameter iMode
	
	; iMode:
	;  0..Datei überschreiben
	;  1..am Datei anhängen
	;  2..in Datei ersetzen - Startadresse in Datei wird in qDstAddr.q übergeben


	Protected iResult.i
	Protected iReturn.i=0
	Protected sPath.s

	sPath=GetPathPart(sFilename)

	If (sPath<>"")
		iResult=CreateDirectory_2(sPath)
		If (iResult>0)
			Debug "Mem_Dump2File - CreateDirectory Error >"+Str(iResult)+"< >"+sPath+"<"
			iReturn=1
		EndIf	
	EndIf

	If (iReturn=0)

		If (iLen=#False)
			iLen=MemorySize(*StartAddr)
		EndIf
		
		If FileSize(sFilename)>0 And iMode>0 ; wenn entweder an Datei angehängt oder in Datei ersetzt werden soll
			iResult=OpenFile(#PB_Any, sFilename, #PB_File_Append)
		Else
			iResult=CreateFile(#PB_Any, sFilename)
		EndIf
	
		If (iResult<>0)
			If iMode=2 ; wenn in Datei ersetzt werden soll
				If qDstAddr<=Lof(iResult) ; wenn die Zieladresse kleiner der Dateigröße ist
					FileSeek(iResult, qDstAddr)
				Else
					FileSeek(iResult, Lof(iResult))         ; springt an das Ende der Datei (das Ergebnis von Lof() wird hierfür verwendet)
				EndIf
			EndIf
			WriteData(iResult, *StartAddr, iLen)
			CloseFile(iResult)
		Else
			Debug "Mem_Dump2File - CreateFile Error >"+Str(iResult)+"< >"+sPath+"<"
			iReturn=2
		EndIf
	EndIf

	ProcedureReturn iReturn
	
EndProcedure


Procedure.s Mem_ReadString(*StartAddr, iLen.i)
	; Liest einen String aus dem Speicher, ersetzt alle Zeichen kleiner $32 durch Leerzeichen und liefert das Ergebnis zurück

	; 20120508 ... liefert die Antwort jetzt als "richtigen" String zurück, also entweder ASCII oder Unicode, je nach Compiler-Einstellung
	
	Protected sDest.s=""
	Protected iCnt.i
	Protected aTemp.a
	Protected *Temp	

	If (iLen>0)	
		*Temp=AllocateMemory(iLen)
	
		If (*Temp)
	
		;Debug "Mem_ReadString - >"+Str(iLen)+"<"
			For iCnt=0 To iLen-1
				aTemp=PeekB(*StartAddr+iCnt)
				If aTemp<32
					aTemp=32
				EndIf
		;		Debug "cnt >"+Str(iCnt)+"< Char >"+Chr(aTemp)+"<"
				PokeB(*Temp+iCnt,aTemp)
					
			Next iCnt
	
			sDest=PeekS(*Temp, iLen, #PB_Ascii )
			FreeMemory(*Temp)
		Else
			Debug "Mem_Readstring - Fehler bei AllocateMemory"
		EndIf
	Else
		Debug "Mem_ReadSTring - iLen=0"
	EndIf
	
;	Debug ">"+sDest+"<"
	
	ProcedureReturn sDest
	
EndProcedure

Procedure.i Mem_WriteString(*StartAddr, sString.s)
	; Schreibt einen String Byte für Byte in den Speicher
	
	Protected iCnt.i
	
	Debug "String >"+sString+"< Len >"+Str(Len(sString))+"<"
	
	;Debug "Mem_ReadString - >"+Str(iLen)+"<"
	For iCnt=1 To Len(sString)
		PokeB(*StartAddr+iCnt-1, Asc(Mid(sString, iCnt, 1)))
	Next iCnt
	
	ProcedureReturn iCnt
	
EndProcedure

Procedure.s Mem_GetLine(*StartAddr, iLineNr.i=1)
	Protected iCnt.i
	Protected iMemSize.i
	Protected aTemp.a
	Protected iNextStart.i
	Protected iLineCnt.i
	Protected sLine.s
	Protected iLastLineChange.i=0
	
	iMemSize=MemorySize(*StartAddr)
	iNextStart=0
	iLineCnt=0
;	Debug "Mem_GetLine - Size >"+Str(iMemSize)+"< Line >"+Str(iLineNr)+"<"
	For iCnt=0 To iMemSize-1 Step 1
		aTemp=PeekB(*StartAddr+iCnt)
		If (aTemp=$0D Or aTemp=$0A)	;wenn ein zeilenvorschub oder carriage return erkannt wird
			iLineCnt+1
;			Debug "Mem_GetLine >"+Str(iLineCnt)+"< Offset >"+Str(iLastCnt)+"< Len >"+Str(iCnt-iLastCnt)+"< >"+PeekS(*StartAddr+iLastCnt,iCnt-iLastCnt)+"<"
			If iLineCnt=iLineNr
				sLine=Mem_ReadString(*StartAddr+iNextStart,iCnt-iNextStart)
				ProcedureReturn sLine
			EndIf

			If (iCnt<iMemSize) ;dann ist noch mind. 1 byte platz - wir können also das folgebyte noch analysieren
				aTemp=PeekB(*StartAddr+iCnt+1)
				If (aTemp=$0D Or aTemp=$0A) ;wenn das Byte danach auch noch LF oder CR ist
					iCnt+1
				EndIf
			EndIf
			iNextStart=iCnt+1
		EndIf
	Next
	
	; wenn es nach dem letzten Zeilenwechsel noch weitere Bytes gibt, dann ist es eine weitere Zeile die nicht mit einem Zeilenwechsel abgeschlossen ist
	If iLastLineChange<iMemSize-1
		iLineCnt+1
		
		If iLineCnt=iLineNr
			sLine=Mem_ReadString(*StartAddr+iNextStart,iMemSize-iNextStart)
			ProcedureReturn sLine
		EndIf		
		
	EndIf	
	
	ProcedureReturn "ERROR"
EndProcedure

Procedure.i Mem_GetLineCnt(*StartAddr)
; 20110204-1235 .. nalor .. ein paar Fehler korrigiert und eingebaut, das eine abschliessende Zeile auch ohne Zeilenwechsel erkannt wird
	Protected iCnt.i
	Protected iMemSize.i
	Protected aTemp.a
	Protected iLineCnt.i
	Protected iLastLineChange.i=0
	
	iMemSize=MemorySize(*StartAddr)

	iLineCnt=0
	For iCnt=0 To iMemSize-1 Step 1
		aTemp=PeekB(*StartAddr+iCnt)
		If (aTemp=$0D Or aTemp=$0A)	;wenn ein zeilenvorschub oder carriage return erkannt wird
			iLineCnt+1
			iLastLineChange=iCnt
			If (iCnt<iMemSize) ;dann ist noch mind. 1 byte platz - wir können also das folgebyte noch analysieren
				aTemp=PeekB(*StartAddr+iCnt+1)
				If (aTemp=$0D Or aTemp=$0A) ;wenn das Byte danach auch noch LF oder CR ist
					iCnt+1
					iLastLineChange=iCnt
				EndIf
			EndIf
		EndIf
	Next
	
	; wenn es nach dem letzten Zeilenwechsel noch weitere Bytes gibt, dann ist es eine weitere Zeile die nicht mit einem Zeilenwechsel abgeschlossen ist
	If iLastLineChange<iMemSize-1
		iLineCnt+1
	EndIf
	
	ProcedureReturn iLineCnt
	
EndProcedure



Procedure.s FormatDateStd(iDate.i, iFormat.i=0)
	
	; 20130602 .. nalor .. erstellt
	
	Select iFormat
		Case 0
			ProcedureReturn FormatDate("%yyyy.%mm.%dd %hh:%ii:%ss", iDate)
		Case 1
			ProcedureReturn FormatDate("%yyyy.%mm.%dd", iDate)
	EndSelect
			
EndProcedure

Procedure.s GetDirectoryName(sFilePath.s)
	Protected sDir.s=GetPathPart(sFilePath)
	
	ProcedureReturn StringField(sDir, CountString(sDir, "\"), "\")
EndProcedure

;- Error Handler

Procedure ErrorHandler()
	
	Protected ErrorMessage$
	
	ErrorMessage$ = "A program error was detected:" + Chr(13) 
	ErrorMessage$ + Chr(13)
	ErrorMessage$ + "Error Message:   " + ErrorMessage()      + Chr(13)
	ErrorMessage$ + "Error Code:      " + Str(ErrorCode())    + Chr(13)  
	ErrorMessage$ + "Code Address:    " + Str(ErrorAddress()) + Chr(13)
	
	If ErrorCode() = #PB_OnError_InvalidMemory   
		ErrorMessage$ + "Target Address:  " + Str(ErrorTargetAddress()) + Chr(13)
	EndIf
	
	If ErrorLine() >=0
		ErrorMessage$ + "Sourcecode line: " + Str(ErrorLine()) + Chr(13)
		ErrorMessage$ + "Sourcecode file: " + ErrorFile() + Chr(13)
	EndIf
	
	MessageRequester("Fehlerinformationen:", ErrorMessage$)
	
	LogFileStd(ErrorMessage$)
	
	End
 
EndProcedure


;- INI Prozeduren
Procedure.s ReadIniValue(sFile.s, sGroup.s, sKeyname.s, sDefaultValue.s="")
;# 20110128-1030 .. nalor .. erstellt
;# 20120514-1150 .. nalor .. DefaultValue mit einfügt
;# 20130516-2230 .. nalor .. wenn die Gruppe nicht vorhanden ist auch den DefaultWert rückliefern
;# 20130524-2235 .. nalor .. wenn das Ergebnis in den Spezial-Anführungszeichen enthalten ist diese wieder entfernen
;# 20140415-2112 .. nalor .. DefaultValue wird jetzt als StandardAntwort gesetzt... wieso war das vorher nicht???

	Protected sResult.s=sDefaultValue
	
	If (OpenPreferences(sFile))	; wenn die settings-datei geöffnet werden kann
		If PreferenceGroup(sGroup)
			sResult=ReadPreferenceString(sKeyname, sDefaultValue)
			
			If (Trim(sResult, "^")<>sResult) ; wenn es in den Spezial-Anführungszeichen gesetzt ist
				sResult=Mid(sResult, 2, Len(sResult)-2)
			EndIf
			
		Else ; es gibt nicht einmal die Gruppe
			sResult=sDefaultValue
		EndIf
		ClosePreferences()
	EndIf
	
	ProcedureReturn sResult
	
EndProcedure

Procedure WriteIniValue(sFile.s, sGroup.s, sKeyname.s, sValue.s)
	;# 20110128-1030 .. nalor .. erstellt
	;# 20110426-1521 .. nalor .. korrigiert - sollte jetzt funktionieren
	;# 20120717-1320 .. nalor .. OpenPreferences prüft nicht ob die Datei zum Schreiben geöffnet werden kann - und ClosePreferences hat keinen sinnvollen Rückgabewert
	;                            daher wird jetzt vorher mit OpenFile geprüft ob die Datei auch zum Schreiben geöffnet werden kann.
	;                .. nalor .. weiters wird noch das Änderungsdatum mit geprüft - länger als 2 Sekunden sollte es echt nicht entfernt sein...
	;# 20130524-2030 .. nalor .. wenn der Wert mit Leerzeichen beginnt oder endet dann wird er in Spezial-Anführungszeichen '^' gesetzt - d.h. es können keine Werte mit diesen Anführungszeichen vorne und hinten gespeichert werden!
	;# 20130920-2125 .. nalor .. Prüfung auf Änderungsdarum verändert: wird jetzt vor und nach dem Schreibvorgang ermittelt und es muss sich verändern - sonst fehler
	;# 20130928-1947 .. nalor .. jetzt wird Änderungsdatum 1Sek vorverlegt und neu geschrieben, damit MUSS es eine Änderung geben wenn die Datei erfolgreich upgedatet wurde!
	
	Protected iTemp.i
	Protected iReturn.i=#True
	Protected FileModified_Before.i
	Protected FileModified_After.i

	iTemp=OpenFile(#PB_Any, sFile)
	
	If (iTemp>0)
		CloseFile(iTemp)
		
		FileModified_Before=GetFileDate(sFile, #PB_Date_Modified)-1 ; -1 damit das Änderungsdatum auch wirklich in der Vergangenheit liegt!
		
		If (SetFileDate(sFile, #PB_Date_Modified, FileModified_Before) And OpenPreferences(sFile) )	; wenn die settings-datei geöffnet werden kann
			Debug "writeinivalue - file >"+sFile+"<geöffnet - Value >"+sValue+"<"
			
			If (Trim(sValue)<>sValue)
				sValue="^"+sValue+"^"
			EndIf
				
			PreferenceGroup(sGroup) ; wählt die Gruppe, wenn sie noch nicht existiert wird sie mit dem nächsten schreibvorgang angelegt
			WritePreferenceString(sKeyname, sValue)
			ClosePreferences()
			
			FileModified_After=GetFileDate(sFile, #PB_Date_Modified)
			
			If (FileModified_After=FileModified_Before)  ; wenn sich das Änderungsdatum nicht verändert hat - dann Fehler
				Debug "File Modified Date has not changed!! Orig >"+FormatDateStd(FileModified_Before)+"< Now >"+FormatDateStd(FileModified_After)+"<"
				iReturn=#False
			EndIf

		Else
			Debug "error open pref or setting modified_date"
			iReturn=#False
		EndIf
	Else
		Debug "WriteIniValue - error open file"
		iReturn=#False
	EndIf
	
	ProcedureReturn iReturn

EndProcedure
; IDE Options = PureBasic 5.42 LTS (Windows - x86)
; CursorPosition = 503
; FirstLine = 490
; Folding = ---
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser
; EnableOnError
; EnableCompileCount = 0
; EnableBuildCount = 0
; EnableExeConstant