
; http://www.purebasic.fr/english/viewtopic.php?f=3&t=51354#p390769

    ; ============================================================
    ; Makros:
    ;     ConsoleHandle() ............ handle of the console window
    ;
    ; Funktionen:
    ;     ConsoleLocation()
    ;         X and Y position of the cursor in the console window
    ;         Returns a long which contains position in COORD format
    ;     ConsoleLocationX()
    ;         X position of the cursor in the console window
    ;     ConsoleLocationY()
    ;         Y position of the cursor in the console window
    ;     ConsoleWidth()
    ;         width of the console window
    ;     ConsoleHeight()
    ;         height of the console window
    ;     ConsoleBufferLocation()
    ;         X and Y position of the cursor in the console screen buffer
    ;         Returns a long which contains position in COORD format
    ;     ConsoleBufferLocationX()
    ;         X position of the cursor in the console screen buffer
    ;     ConsoleBufferLocationY()
    ;         Y position of the cursor in the console screen buffer
    ;     ConsoleBufferWidth()
    ;         width of the console screen buffer
    ;     ConsoleBufferHeight()
    ;         height of the console screen buffer
    ;     ConsoleBufferLocate()
    ;         similar to ConsoleLocate() but positions the cursor
    ;         inside the console screen buffer
    ;     ConsoleMoveUp()
    ;         moves the cursor up one line
    ;         sets the cursor to the left postion
    ;     ConsoleMoveUp( CountLines )
    ;         moves the cursor up [CountLines] lines
    ;         sets the cursor to the left postion
    ;     ConsoleDeletePrevLines()
    ;         moves the cursor up one line
    ;         sets the cursor to the left postion
    ;         deletes the whole Line (overwrite With spaces)
    ;     ConsoleDeletePrevLines( CountLines )
    ;         moves the cursor up [CountLines] lines
    ;         sets the cursor to the left postion
    ;         deletes the whole Line (overwrite with spaces)
    ;     GetConsoleTitle()
    ;         returns a string, which contains the console title
    ;
    ; ============================================================

    Macro ConsoleHandle()
       GetStdHandle_( #STD_OUTPUT_HANDLE )  ; GetConsoleWindow_() funktioniert nicht
    EndMacro

    Structure tConsole_COORD
       StructureUnion
          coord.COORD
          long.l
       EndStructureUnion
    EndStructure

    Procedure.l ConsoleLocation()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       Protected location.tConsole_COORD
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       location\coord\x = ConsoleBufferInfo\dwCursorPosition\x - ConsoleBufferInfo\srWindow\left
       location\coord\y = ConsoleBufferInfo\dwCursorPosition\y - ConsoleBufferInfo\srWindow\top
       
       ProcedureReturn location\long
    EndProcedure

    Procedure   ConsoleLocationX()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\dwCursorPosition\x - ConsoleBufferInfo\srWindow\left
    EndProcedure

    Procedure   ConsoleLocationY()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\dwCursorPosition\y - ConsoleBufferInfo\srWindow\top
    EndProcedure

    Procedure.l ConsoleBufferLocation()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       Protected location.tConsole_COORD
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       location\coord\x = ConsoleBufferInfo\dwCursorPosition\x
       location\coord\y = ConsoleBufferInfo\dwCursorPosition\y
       
       ProcedureReturn location\long
    EndProcedure

    Procedure   ConsoleBufferLocationX()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\dwCursorPosition\x
    EndProcedure

    Procedure   ConsoleBufferLocationY()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\dwCursorPosition\y
    EndProcedure

    Procedure   ConsoleWidth()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\srWindow\right - ConsoleBufferInfo\srWindow\left + 1
    EndProcedure

    Procedure   ConsoleHeight()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\srWindow\bottom - ConsoleBufferInfo\srWindow\top + 1
    EndProcedure

    Procedure   ConsoleBufferWidth()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\dwSize\x
    EndProcedure

    Procedure   ConsoleBufferHeight()
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       ProcedureReturn ConsoleBufferInfo\dwSize\y
    EndProcedure

    Procedure   ConsoleMoveUp( CountLines = 1 )
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole, x, y
       Protected location.tConsole_COORD
       
       If CountLines < 1 : ProcedureReturn #False : EndIf
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       location\coord = ConsoleBufferInfo\dwCursorPosition
       location\coord\x = 0
       location\coord\y - CountLines
       If location\coord\y < 0 : location\coord\y = 0
          ElseIf location\coord\y >= ConsoleBufferInfo\dwSize\y : location\coord\y = ConsoleBufferInfo\dwSize\y - 1 : EndIf
       SetConsoleCursorPosition_( hConsole, location\long )
       
       ProcedureReturn #True
    EndProcedure

    Procedure   ConsoleDeletePrevLines( CountLines = 1 )
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole, x, y
       Protected location.tConsole_COORD
       
       If CountLines < 1 : ProcedureReturn #False : EndIf
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       location\coord\x = 0
       location\coord\y = ConsoleBufferInfo\dwCursorPosition\y
       While CountLines And location\coord\y
          location\coord\y - 1
          SetConsoleCursorPosition_( hConsole, location\long )
          Print( Space(ConsoleBufferInfo\dwSize\x) )
          If CountLines = 1
             SetConsoleCursorPosition_( hConsole, location\long )
          EndIf
          CountLines - 1
       Wend
       
       ProcedureReturn #True
    EndProcedure

    Procedure   ConsoleBufferLocate( x, y )
       Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
       Protected hConsole
       Protected location.tConsole_COORD
       
       If y < 0 Or y < 0
          ; x or y outside the console screen buffer
          ProcedureReturn #False
       EndIf
       
       hConsole = ConsoleHandle()
       GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
       
       If y >= ConsoleBufferInfo\dwSize\y Or x >= ConsoleBufferInfo\dwSize\x
          ; x or y outside the console screen buffer
          ProcedureReturn #False
       EndIf
       
       location\coord\x = x
       location\coord\y = y
       SetConsoleCursorPosition_( hConsole, location\long )
       
       ProcedureReturn #True
    EndProcedure

    Procedure.s GetConsoleTitle()
       Protected title.s = Space(1024)
       GetConsoleTitle_( @title, 1024 )
       ProcedureReturn title
    EndProcedure
    
    
    
    
    
;     
;     
;     
;         Macro WaitKey()
;        While Inkey() = "" : Delay(100) : Wend
;     EndMacro
; 
;     Define i
; 
;     OpenConsole()
; 
;     For i = 0 To 100
;        PrintN( Str(i) )
;     Next i
; 
; 
;     WaitKey()
; 
;     ConsoleMoveUp( 10 )
;     For i = 1001 To 1010
;        PrintN( "Overwrite last 10 lines (100 - 110) with " + Str(i) )
;     Next i
;     WaitKey()
; 
;     ConsoleDeletePrevLines( 10 )
;     PrintN( "Deleted last 10 lines" )
;     WaitKey()
; 
;     ConsoleMoveUp( 20 )
;     PrintN( "Move up 20 lines and overwrite line with something else ..." )
;     WaitKey()
; 
;     ConsoleBufferLocate( 0, 0 )
;     Print( " <-- This is position (0,0) in screen buffer" )
;     ConsoleBufferLocate( 0, 0 )
;     WaitKey()
; 
;     ConsoleBufferLocate( 0, ConsoleBufferHeight()-1 )
;     Print( RSet("This is position (" + Str(ConsoleBufferWidth()-1) + "," + Str(ConsoleBufferHeight()-1) + ") in screen buffer -->", ConsoleBufferWidth()-1, " "))
;     WaitKey()
; 
;     CloseConsole()
;     End
;     

Structure PCONSOLE_SCREEN_BUFFER_INFO Align #PB_Structure_AlignC 
  dwSize.COORD
  dwCursorPosition.COORD
  wAttributes.u
  srWindow.SMALL_RECT
  dwMaximumWindowSize.COORD
EndStructure

Procedure ConsoleGetColor(iMode.i=0)
	
	Protected Color.i
	Protected iHdl.i
	Protected Info.PCONSOLE_SCREEN_BUFFER_INFO

	iHdl=ConsoleHandle()
	If iHdl
		If GetConsoleScreenBufferInfo_(iHdl, @Info)
			
			Select iMode
				Case 0 ; alle Farben gemeinsam
					Color=Info\wAttributes&$FF
					
				Case 1 ; nur Character-Color
					Color=Info\wAttributes&$0F
					
				Case 2 ; nur Background-Color
					Color=(Info\wAttributes&$F0)>>4
			EndSelect
		Else
			Color=-2
		EndIf	
	Else
		Color=-1
	EndIf
	
	ProcedureReturn Color
	
EndProcedure

Procedure ConsoleSetColor(iColor.i)
	
	ConsoleColor(iColor&$0F, (iColor&$F0)>>4)
	
EndProcedure

Procedure Console_GetBufferLocation(*Location.COORD)
	Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
	Protected hConsole
	
	hConsole = ConsoleHandle()
	GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
	
	*Location\x = ConsoleBufferInfo\dwCursorPosition\x
	*Location\y = ConsoleBufferInfo\dwCursorPosition\y
	
EndProcedure

Procedure Console_SetBufferLocation(*Location.COORD)
	Protected ConsoleBufferInfo.CONSOLE_SCREEN_BUFFER_INFO
	Protected hConsole
	
	If *Location\x<0 Or *Location\y<0 ; x or y outside the console screen buffer
		ProcedureReturn #False
	EndIf
	
	hConsole = ConsoleHandle()
	GetConsoleScreenBufferInfo_( hConsole, @ConsoleBufferInfo )
	
	If *Location\y >= ConsoleBufferInfo\dwSize\y Or *Location\x >= ConsoleBufferInfo\dwSize\x ; x Or y outside the console screen buffer
		ProcedureReturn #False
	EndIf
	
	SetConsoleCursorPosition_(hConsole, *Location\x + *Location\y<<16 )
	
	ProcedureReturn #True	
EndProcedure

Procedure Console_PrintCenter(sTxt.s, iNewLine.i=#False )
	Protected iWidth.i
	Protected iLen.i
	Protected iFront.i
	
	iWidth=ConsoleWidth()
	iLen=Len(sTxt)
	
	If iLen<iWidth
		iFront=(iWidth-iLen)/2
		sTxt=Space(iFront)+sTxt+Space(iWidth-iLen-iFront-1)
; 		Debug "Width >"+iWidth+"< LEN >"+iLen+"< Front >"+iFront+"< >"+Len(sTxt)
	EndIf
	
	If iNewLine
		PrintN(sTxt)
	Else
		Print(sTxt)
	EndIf

EndProcedure

Procedure Console_ClearLine()

	Print(Space(ConsoleWidth()))

EndProcedure

Procedure.s Console_GetString(sCharAllow.s, iMaxLen.i, iAllowEscape.i=#False)
	
	Protected StartPos.COORD
	Protected CurPos.COORD
	
	Protected iCursorPos.i=0
	Protected iCursorMaxPos.i=0
	
	Protected sKeyChar.s
	Protected iKeyVal.i
	Protected sFinalString.s
	
	Console_GetBufferLocation(@StartPos)
	
	Print(Space(iMaxLen))
	Console_SetBufferLocation(@StartPos)
	
	Repeat
		sKeyChar = Inkey()
      
		If sKeyChar<>"" ; dann wurde eine normale Taste gedrückt
      	If FindString(sCharAllow, sKeyChar) ; wenn das Zeichen erlaubt ist
      		
      		If iCursorPos<iMaxLen
	      		Print(sKeyChar)
      		
	      		If iCursorPos=Len(sFinalString) ; wenn sich der Cursor am Ende befindet
	      			sFinalString+sKeyChar
	      			iCursorMaxPos+1
	      		Else
	      			sFinalString=Mid(sFinalString, 0, iCursorPos)+sKeyChar+Mid(sFinalString, iCursorPos+2) ; in der Mitte einfügen
	      			
	      		EndIf
	      		Debug sFinalString
	      		iCursorPos+1
      		EndIf
      	Else
      		Select RawKey()
      			Case 8 ; Backspace
      				If iCursorPos>0
      					Console_GetBufferLocation(@CurPos)
							sFinalString=Mid(sFinalString, 0, iCursorPos-1)+Mid(sFinalString, iCursorPos+1)
							
							Console_SetBufferLocation(@StartPos)
							Print(sFinalString+" ")
							CurPos\x-1
							Console_SetBufferLocation(@CurPos)							
							iCursorPos-1
							iCursorMaxPos-1
						EndIf      				
      				
					Case 13 ; Enter
						Debug "FinalValue >"+sFinalString+"<"
						Break
						
					Case 27 ; Escape
						Debug "ESCAPE pressed"
						If iAllowEscape
							sFinalString=""
							Break
						EndIf
						
      			Default
      				Debug "Char >"+sKeyChar+"< raw code of: "+Str(RawKey())
      				
      				
      		EndSelect
      		
      	EndIf
      	
      ElseIf RawKey()
      	iKeyVal=RawKey()
      	
      	Select iKeyVal
      		Case 37 ; Cursor Left
      			If iCursorPos>0
      				Console_GetBufferLocation(@CurPos)
      				CurPos\x-1
      				Console_SetBufferLocation(@CurPos)
						iCursorPos-1
					EndIf
      			
				Case 39 ; Cursor Right
					If iCursorPos<iCursorMaxPos
						Console_GetBufferLocation(@CurPos)
						CurPos\x+1
						Console_SetBufferLocation(@CurPos)
						iCursorPos+1
					EndIf
					
				Case 46 ; Delete Key
					If iCursorPos<iCursorMaxPos
						Console_GetBufferLocation(@CurPos)
						sFinalString=Mid(sFinalString, 0, iCursorPos)+Mid(sFinalString, iCursorPos+2)
						Console_SetBufferLocation(@StartPos)						
						Print(sFinalString+" ")
						Console_SetBufferLocation(@CurPos)						
						iCursorMaxPos-1
					EndIf					
      			
      		Default
      			Debug ("KeyVal >"+iKeyVal)
      	EndSelect
      	
        
      Else
        Delay(20) ; Don't eat all the CPU time, we're on a multitask OS
      EndIf
      
	ForEver

	ProcedureReturn sFinalString	
	
EndProcedure

Procedure PrintC(sText.s, iCharColor.i=-1, iBackColor.i=-1, iNewLine.i=#False)
	Protected iColor.i
	
	iColor=ConsoleGetColor()
	
	If iCharColor=-1
		iCharColor=iColor&$0F
	EndIf
	
	If iBackColor=-1
		iBackColor=(iColor&$F0)>>4
	EndIf
		
	ConsoleColor(iCharColor, iBackColor)
	If iNewLine
		PrintN(sText)
	Else
		Print(sText)
	EndIf
	ConsoleSetColor(iColor)	

EndProcedure

Procedure PrintNC(sText.s, iCharColor.i=-1, iBackColor.i=-1)
	
	PrintC(sText, iCharColor, iBackColor, #True)
	
EndProcedure

; IDE Options = PureBasic 5.22 LTS (Windows - x86)
; CursorPosition = 531
; FirstLine = 505
; Folding = -----
; EnableUnicode
; EnableThread
; EnableXP
; EnableUser
; EnableCompileCount = 12
; EnableBuildCount = 0
; EnableExeConstant