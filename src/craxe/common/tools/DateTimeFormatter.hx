package craxe.common.tools;

import craxe.common.tools.DateTime;


class DateTimeFormatter {

    static inline function pad(s: String) {
        final full = "00" + s;
        return full.substring(full.length - 2);
    }

    static function _d(d: DateRec) return pad(Std.string(d.day));
    static function _m(d: DateRec) return pad(Std.string(d.month));
    static function _y(d: DateRec) return pad(Std.string(d.year % 100));
    static function _Y(d: DateRec) return Std.string(d.year);
    static function _dmin(d: DateRec) return Std.string(d.day);
    static function _mmin(d: DateRec) return Std.string(d.month);
    static function _ymin(d: DateRec) return Std.string(d.year % 100);

    static function _H(t: TimeRec) return pad(Std.string(t.hour));
    static function _I(t: TimeRec) {final h = Math.floor(t.hour % 12); return pad(Std.string(h > 0 ? h : 12));};
    static function _M(t: TimeRec) return pad(Std.string(t.minute));
    static function _S(t: TimeRec) return pad(Std.string(Math.floor(t.sec)));
    static function _Hmin(t: TimeRec) return Std.string(t.hour);
    static function _Imin(t: TimeRec) return Std.string(t.hour % 12 + 1);
    static function _Mmin(t: TimeRec) return Std.string(t.minute);
    static function _Smin(t: TimeRec) return Std.string(Math.floor(t.sec));
    static function _p(t: TimeRec) return t.hour < 12 ? "AM" : "PM";
    //static function _f(t: TimeRec) return MathX.frac(t.sec)  < 12 ? "AM" : "PM";
    static function _u(d: DateTime) return Std.string(d.dayOfWeek() + 1);
    static function _w(d: DateTime) return Std.string((d.dayOfWeek() + 7 - Sun) % 7);
    static function _U(d: DateTime) return pad(Std.string(d.ISOWeekNumber(Sun, 4).week));
    static function _W(d: DateTime) return pad(Std.string(d.ISOWeekNumber(Mon, 4).week));

    static function analyze(f: String, result: Array<DTFPart>)
    {
        inline function error(s: String) {
            result.resize(0);
            result.push(Error(s));
        }

        var p = 0;	
        while (p < f.length) {
            var n = f.indexOf('%', p);
            if (n >= 0) {
                if (n > p) result.push(Lit(f.substring(p, n)));
                n++;
                if (n < f.length) {
                    switch StringTools.fastCodeAt(f, n) {
                        case 'd'.code : result.push(DatePart(_d));
                        case 'm'.code : result.push(DatePart(_m));
                        case 'y'.code : result.push(DatePart(_y));
                        case 'H'.code : result.push(TimePart(_H));
                        case 'I'.code : result.push(TimePart(_I));
                        case 'M'.code : result.push(TimePart(_M));
                        case 'S'.code : result.push(TimePart(_S));
                        case 'Y'.code : result.push(DatePart(_Y));
                        case 'p'.code : result.push(TimePart(_p));
                        case '%'.code : result.push(Lit('%'));
                        case 't'.code : result.push(Lit('\t'));
                        case 'n'.code : result.push(Lit('\n'));
                        case 'w'.code : result.push(DateTimePart(_w));
                        case 'W'.code : result.push(DateTimePart(_W));

                        case '-'.code : {
                            n++;
                            if (n < f.length) {
                                switch StringTools.fastCodeAt(f, n) {
                                    case 'd'.code : result.push(DatePart(_dmin));
                                    case 'm'.code : result.push(DatePart(_mmin));
                                    case 'y'.code : result.push(DatePart(_ymin));
                                    case 'H'.code : result.push(TimePart(_Hmin));
                                    case 'I'.code : result.push(TimePart(_Imin));
                                    case 'M'.code : result.push(TimePart(_Mmin));
                                    case 'S'.code : result.push(TimePart(_Smin));
                                    case var e: 
                                        return error('unsupported code %$e in pattern $f');
                                }
                            } else {
                                return error('unexpected end of string at code %- in pattern $f');
                            }
                            p = n + 1;
                            continue;
                        }
                        case _ :
                            result.resize(0);
                            result.push(DateFormat);
                            return;
                    }
                }
                p = n + 1;
            } else {
                result.push(Lit(f.substring(p)));
                break;
            }
        }
    }

    static var _cache: Map<String, DateTimeFormatter> = [];

    public static function format(d: DateTime, f: String) {
        var formatter = _cache.get(f);
        if (formatter == null) {
            formatter = new DateTimeFormatter(f);
            _cache.set(f, formatter);
        }
        return formatter.doFormat(d);
    }

    var f: String;
    final action: Array<DTFPart> = [];
    function new(f: String) {
        this.f = f;
        analyze(f, action);
    }

    function doFormat(d: DateTime): String {
        var result = "";
        var dr : DateRec = null;
        var tr : TimeRec = null;
        for (a in action) {
            switch a {
                case Lit(s): result += s;
                case DatePart(call):
                    if (dr == null) dr = d.decode(); 
                    result += call(dr);
                case TimePart(call):
                    if (tr == null) tr = d.decodeTime();
                    result += call(tr);
                case DateTimePart(call): result += call(d);
                case DateFormat: result += DateTools.format(d, f);
                case Error(s): throw s;
            }
        }
        return result;
    }
}

private enum DTFPart {
    Lit(s: String);
    DatePart(call: (d: DateRec) -> String);
    TimePart(call: (t: TimeRec) -> String);
    DateTimePart(call: (d: DateTime) -> String);
    DateFormat;
    Error(s: String);
}
