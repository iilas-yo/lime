package lime.system;

@:cppFileCode('
	#include <Windows.h>
')

class Windows {
	public static function setWindowPos(post:Int, x:Int, y:Int, cx:Int, cy:Int, style:Int) {
		untyped __cpp__('
			HWND hwnd = GetActiveWindow();
			SetWindowPos(hwnd, (HWND)post, x, y, cx, cy, style);
		');
	}
}