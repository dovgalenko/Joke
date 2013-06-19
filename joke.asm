include macros.inc

@Start
@Uses Advapi32, User32, Kernel32, Gdi32

DEBUG Equ TRUE

Randomize     PROTO
MakeRegistry  PROTO
WndProc       PROTO :DWORD, :DWORD, :DWORD, :DWORD

.data
Jokes       Equ 65

dlgTitle    Db  "!!!WARNING!!!", 0

tArea       RECT <95, 25, 325, 85>

mCaption    Db  'Joke v1.1.100', 0
mText       Db  'The CHEMI$T Copyright(C)Y2K', 13, 10, 'Выгрузить из памяти?', 0


logFnt      LOGFONT  <16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, \
                     OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
                     FF_MODERN or DEFAULT_PITCH, 'Times New Roman Cyr'>

IsActive    Dd  TRUE

.data?
hDC         Dd  ?
hWnd	    Dd  ?
hFNT        Dd  ?
hTimer      Dd  ?
hBitmap     Dd  ?
hInstance   Dd  ?

aText       Db  256 Dup(?)

.code
WinMain Proc
IFNDEF DEBUG
  ; Создание нашей записи в реестре
  ;invoke MakeRegistry
  ; Ищем, есть ли метка, повторно не запускаемся.(Global Atom действует
  ; в течение всего сеанса Windows. В следствие чего, чтоб загрузить прогу
  ; повторно - придется перезагрузиться.
  invoke GlobalFindAtom, ADDR mCaption
  .if eax == 0
    invoke GlobalAddAtom, ADDR mCaption

ENDIF
    ; Говорим Windows, что запущен скринсейвер, в этом случае не будут
    ; работать ни Alt-Tab, ни Ctrl-Alt-Del
    invoke SystemParametersInfo, SPI_SCREENSAVERRUNNING, 1, ADDR IsActive, 0
    Mov    hInstance, @Result(GetModuleHandle, NULL)

    ; Выбираем номер строки
    invoke Randomize
    ; Загружаем строку из ресурсов.
    invoke LoadString, hInstance, eax, ADDR aText, 256

    ; Выдаем окно программы
    invoke DialogBoxParam, hInstance, 500, 0, ADDR WndProc, 0

    ; Убираем пометку о запуске скринсейвера
    invoke SystemParametersInfo, SPI_SCREENSAVERRUNNING, 0, ADDR IsActive, 0

IFNDEF DEBUG
  .endif
ENDIF

    invoke ExitProcess, 0
WinMain Endp

; Процедура диалогового окна
WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

        LOCAL   bDC    :DWORD
        LOCAL cArea    :RECT
        LOCAL sPaint   :PAINTSTRUCT

     .if uMsg == WM_TIMER
        invoke KillTimer, hWin, hTimer
        invoke EndDialog, hWin, 0

     .elseif uMsg == WM_RBUTTONDBLCLK
        mov    eax, wParam
        and    eax, MK_CONTROL
        .if eax == MK_CONTROL
          mov    eax, lParam
          mov    bx, ax
          shr    eax, 16
          .if ((bx > 0bh) && (ax > 0Eh)) && ((bx < 5Ch) && (ax < 49h))
             invoke MessageBox, hWin, ADDR mText, ADDR mCaption, MB_YESNO or MB_ICONQUESTION
               .if eax == IDYES
                  invoke PostMessage, hWnd, WM_QUIT, 0, 0
                  invoke EndDialog, hWin, 0
               .endif
          .endif
        .endif

     .elseif uMsg == WM_INITDIALOG
        invoke GetSystemMetrics, SM_CXSCREEN
        shr    eax, 1
        sub    eax, 171 // Half of the width of our program window
        mov    edx, eax
        push   edx
        invoke GetSystemMetrics, SM_CYSCREEN
        pop    edx
        shr    eax, 1
        sub    eax, 52 // Half of the height of our program window
        invoke SetWindowPos, hWin, HWND_TOPMOST, edx, eax, 342, 96, SWP_NOCOPYBITS

        invoke SendMessage, hWin, WM_SETTEXT, 0, ADDR dlgTitle
        invoke SetTimer, hWin, 1, 180000, NULL
        mov    hTimer, eax

     .elseif uMsg == WM_PAINT
        ; Отрисовка экрана.
        mov    hDC, @Result(BeginPaint, hWin, ADDR sPaint)
        ; Загружаем битмап
        mov    hBitmap, @Result(LoadBitmap, hInstance, 512)
        ; Создаем, "совместимый" с нашим, контекст
        mov    bDC, @Result(CreateCompatibleDC, hDC)
        ; Выбираем на созданном контексте битмап
        invoke SelectObject, bDC, hBitmap
        ; Растягиваем битмап на всю площадь и переносим на наше окно
        invoke GetClientRect, hWin, ADDR cArea
        invoke StretchBlt, hDC, 0, 0, cArea.right, cArea.bottom, bDC, 0, 0, 342, 96, SRCCOPY
        ; Создаем шрифт
        mov    hFNT, @Result(CreateFontIndirect, ADDR logFnt)
        ; Выбираем его
        invoke SelectObject, hDC, hFNT
        ; Выставляем бэк ...
        invoke GetBkColor, hDC
        push   eax
        invoke SetBkColor, hDC, 0
        ; цвет текста
        pop    eax
        invoke SetTextColor, hDC, eax
        ; Рисуем надпись.
        invoke DrawText, hDC, ADDR aText, -1, ADDR tArea, DT_VCENTER or DT_LEFT or DT_WORDBREAK
        ; Закругляемся и удаляем все объекты
        invoke EndPaint, hWin, ADDR sPaint
        invoke DeleteObject, hBitmap
        invoke DeleteObject, hFNT
        invoke DeleteDC, bDC
     .endif
     xor eax, eax
     ret
WndProc Endp

.data
hKey            Db   'Joke', 0
hDir            Db   'Software\Microsoft\Windows\CurrentVersion\Run', 0

.code
MakeRegistry Proc
    LOCAL  ReturnValue :DWORD
    LOCAL  hTest       :DWORD
    LOCAL  Buffer[512] :BYTE

    invoke GetModuleFileName, hInstance, ADDR Buffer, 512
    ; Открытие ключа в реестре
    invoke RegOpenKeyEx, HKEY_CURRENT_USER, ADDR hDir, 0, KEY_ALL_ACCESS, ADDR hTest
    .if eax != ERROR_SUCCESS  ; Ключ не существует!
      ; Создаем
      invoke RegCreateKeyEx, HKEY_CURRENT_USER, ADDR hDir, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, ADDR hTest, ADDR ReturnValue
    .endif
    invoke lstrlen, ADDR Buffer
    ; Сохраняем значение
    invoke RegSetValueEx, hTest, ADDR hKey, 0, REG_SZ, ADDR Buffer, eax
    ; Закрываем ключ
    invoke RegCloseKey, hTest
    ret
MakeRegistry Endp

.data
_floor  Dd  Jokes
_seed   Dd  11
_sum    Dd  100
_data   Dd  3

.code
;
;       Простейший генератор псевдослучайных чисел,
;    в eax возвращает число в диапазоне от 0 до Jokes.
Randomize    Proc

    LOCAL  sTime: SYSTEMTIME

    invoke GetSystemTime, ADDR sTime

    xor   eax, eax
    mov   ax, sTime.wSecond
    mov   _seed, eax

    finit
    fwait

    fild  _floor

    fild  _seed
    fild  _sum
    fdiv            ; (_seed / 100)
    fldpi
    fadd            ; (_seed / 100) + pi
                    ; 3.14 -> 3.80

    fild  _data
    fsub            ; 0 < rnd < 1
    fmul            ; x * _floor
    frndint

    fist  _sum
    mov   eax, _sum
    ret
Randomize    Endp

        end WinMain
