package craxe.common;

/**
 * Indent type
 */
enum IndentType {
	None;
	Same;
	Inc;
	Dec;
}

enum CallbackResult {
	Str(v: String);
	Data(v: String);
}
/**
 * Buffer item
 */
enum BufferItem {
	Data(s:String);
	Line(v:IndentType);
	Indent(v:IndentType);
	Call(cb: Int->CallbackResult);
	Hook;
	HookResult(hr: CallbackResult);
	Sub(sub: IndentStringBuilder);
}

/**
 * For string builder with indent
 */
class IndentStringBuilder {
	/**
	 * Count of spaces to indent
	 */
	static inline final INDENT_SPACE_COUNT = 4;

	/**
	 * Size of indent
	 */
	final indentSize:Int;

	/**
	 * String builder
	 */
	var buffer:Array<BufferItem>;

	#if (false)
	/**
	 * Indent string
	 */
	var indentStr:String;
	#end

	/**
	 * Current indent
	 */
	var indent(default, set):Int;

	public function set_indent(value:Int):Int {
		indent = value;
		return indent;
	}

	/**
	 * Cursor on current item
	 */
	public var currentItem(default, null):BufferItem;

	/**
	 * Calculate indent string
	 */
	public function calcIndent(ind:Int):String {
		var indStr = "";
		for (i in 0...ind * indentSize)
			indStr += " ";

		return indStr;
	}

	public function renderIndent(indent: Int, s: String) {

	}
	/**
	 * Constructor
	 */
	public function new(indentSize = INDENT_SPACE_COUNT) {
		this.indentSize = indentSize;
		buffer = new Array<BufferItem>();
		indent = 0;
		// indentStr = "";
	}

	/**
	 * Increment indent
	 */
	public inline function inc() {
		currentItem = Indent(Inc);
		buffer.push(currentItem);
	}

	/**
	 * Decrement indent
	 */
	public inline function dec() {
		currentItem = Indent(Dec);
		buffer.push(currentItem);
	}

	/**
	 * Add value to buffer without indent
	 */
	public inline function add(value:String) {
		currentItem = Data(value);
		buffer.push(currentItem);
	}

	/**
	 * Add new Line
	 */
	public function addNewLine(indent:IndentType = None, addIfLine = false) {
		function addLine() {
			currentItem = Line(indent);
			buffer.push(currentItem);
		}

		if (addIfLine) {
			addLine();
		} else {
			switch currentItem {
				case Line(v):
					buffer.push(Indent(indent));
				default:
					addLine();
			}
		}
	}

	/**
	 * Helps to add break
	 * addNewLine(None)
	 * addNewLine(None, true)
	 */
	public inline function addBreak() {
		addNewLine();
		addNewLine(None, true);
	}

	/**
	 * Add a lazy callback
	 * @param cb lazy callback
	 */
	public function addCallback(cb: Int->CallbackResult) {
		buffer.push(Call(cb));
	}

	public function addHook(): Int {
		return buffer.push(Hook) - 1;
	}

	public function resolveHook(id: Int, data: CallbackResult) {
		buffer[id] = HookResult(data);
	}

	public function addSub(sub: IndentStringBuilder) {
		buffer.push(Sub(sub));
	}

	/**
	 * Return string
	 */
	public function toString() {
		var res = new StringBuf();

		var ind = 0;
		var indStr = "";

		function proccIndent(v:IndentType) {
			switch v {
				case None:
					ind = 0;
				case Same:
				case Inc:
					ind += 1;
				case Dec:
					ind -= 1;
					if (ind < 0)
						ind = 0;
			}
		}

		var state = 0;

		for (item in buffer) {
			function addData(s: String) {
				if (state != 1) {
					indStr = calcIndent(ind);
					res.add(indStr);
				}
				res.add(s);
				state = 1;
			}
			function perform(item: BufferItem) {
				switch item {
					case Data(s):
						addData(s);
					case Line(v):
						state = 2;
						res.add("\n");
						proccIndent(v);
					case Indent(v):
						state = 3;
						proccIndent(v);
					case Call(cb):
						switch cb(ind) {
							case Str(v): res.add(v);
							case Data(v): addData(v);
						}
					case Hook: // not resolved skip
					case HookResult(hr):
						switch hr {
							case Str(v): res.add(v);
							case Data(v): addData(v);
						}
					case Sub(sub):
						for (it in sub.buffer)
							perform(it);
				}					
			}
			perform(item);
		}

		return res.toString();
	}
}
