package lime.system;

@:cppFileCode('
	#include <Windows.h>
	#include <windowsx.h>
	#include <cstdio>
	#include <iostream>
	#include <tchar.h>
	#include <dwmapi.h>
	#include <winuser.h>
	#include <winternl.h>
	#include <Shlobj.h>
	#include <commctrl.h>
	#include <string>

	#include <chrono>
	#include <thread>

	#define UNICODE

	#pragma comment(lib, "Dwmapi")
	#pragma comment(lib, "ntdll.lib")
	#pragma comment(lib, "user32.lib")
	#pragma comment(lib, "Shell32.lib")
	#pragma comment(lib, "gdi32.lib")
	#pragma comment(lib, "Advapi32")
')

class Windows {
	@:functionCode('
		HWND hwnd = GetActiveWindow();
		SetWindowPos(hwnd, (HWND)post, x, y, cx, cy, style);
	')
	public static function setWindowPos(post:Int, x:Int, y:Int, cx:Int, cy:Int, style:Int) {}

	@:functionCode('
		HWND hwnd = GetActiveWindow();
		LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);

		if (hide == true) {
			exStyle &= WS_EX_APPWINDOW;
			exStyle |= WS_EX_TOOLWINDOW;
		} else {
			exStyle |= WS_EX_APPWINDOW;
			exStyle &= WS_EX_TOOLWINDOW;
		}

		SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);
	')
	public static function hideWindowInTab(hide:Bool):Bool {
		return hide;
	}

	public static function setWindowDarkColorMode(bool:Bool):Bool {
		var dark:Int = bool ? 1 : 0;
		untyped __cpp__("
			int darkMode = dark;
			HWND window = GetActiveWindow();
			if (S_OK != DwmSetWindowAttribute(window, 19, &darkMode, sizeof(darkMode))) {
				DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE, &darkMode, sizeof(darkMode));
			}
			UpdateWindow(window);
		");
		return bool;
	}

	@:functionCode('
        HWND window = GetActiveWindow();

		auto color = RGB(r, g, b);

        if (S_OK != DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF))) {
            DwmSetWindowAttribute(window, 35, &color, sizeof(COLORREF));
        }

		if (S_OK != DwmSetWindowAttribute(window, 34, &color, sizeof(COLORREF))) {
            DwmSetWindowAttribute(window, 34, &color, sizeof(COLORREF));
        }

        UpdateWindow(window);
    ')
	public static function setWindowBorderColor(r:Int, g:Int, b:Int) {}

	@:functionCode('
		HWND hwnd = GetActiveWindow();
		if (hwnd) {
			SendMessage(hwnd, WM_SETICON, ICON_SMALL, (LPARAM)nullptr);
			SendMessage(hwnd, WM_SETICON, ICON_BIG, (LPARAM)nullptr);
			LONG lStyle = GetWindowLong(hwnd, GWL_STYLE);
			lStyle &= ~WS_SYSMENU;
			SetWindowLong(hwnd, GWL_STYLE, lStyle);
		}
    ')
	public static function removeAllWindowButtons() {}

	@:functionCode('
		HWND hwnd = GetActiveWindow();

		if (hwnd) {
			LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);

			DWM_BLURBEHIND blurBehind = {};
			blurBehind.dwFlags = DWM_BB_ENABLE | DWM_BB_BLURREGION;
			blurBehind.hRgnBlur = CreateRectRgn(-1, -1, 0, 0);
			blurBehind.fEnable = transparent;

			DwmEnableBlurBehindWindow(hwnd, &blurBehind);

			if (transparent) {
				exStyle |= WS_EX_LAYERED | WS_EX_TRANSPARENT;
			} else {
				exStyle &= ~WS_EX_LAYERED;
				exStyle &= ~WS_EX_TRANSPARENT;
			}

			SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);
		}
	')
	public static function setWindowTransparent(transparent:Bool):Bool {
		return transparent;
	}
}