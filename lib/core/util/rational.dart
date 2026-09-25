/// 精确分数（音乐时值），单位=四分音符。自动约分，不可变。
class Rational implements Comparable<Rational> {
  const Rational(int numerator, int denominator)
      : assert(denominator > 0),
        numerator_ = numerator,
        denominator_ = denominator;

  const Rational.zero()
      : numerator_ = 0,
        denominator_ = 1;
  const Rational.one()
      : numerator_ = 1,
        denominator_ = 1;

  factory Rational.fromJson(Map<String, dynamic> json) => Rational(
        json['n'] as int,
        json['d'] as int,
      );

  final int numerator_;
  final int denominator_;

  int get numerator => numerator_;
  int get denominator => denominator_;

  bool get isZero => numerator_ == 0;
  bool get isNegative => numerator_ < 0;

  Rational operator +(Rational other) => Rational(
        numerator_ * other.denominator_ + other.numerator_ * denominator_,
        denominator_ * other.denominator_,
      );
  Rational operator -(Rational other) => Rational(
        numerator_ * other.denominator_ - other.numerator_ * denominator_,
        denominator_ * other.denominator_,
      );
  Rational operator *(Rational other) => Rational(
        numerator_ * other.numerator_,
        denominator_ * other.denominator_,
      );
  Rational operator /(Rational other) => Rational(
        numerator_ * other.denominator_,
        denominator_ * other.numerator_,
      );

  Rational operator -() => Rational(-numerator_, denominator_);

  @override
  int compareTo(Rational other) =>
      (numerator_ * other.denominator_ - other.numerator_ * denominator_)
          .compareTo(0);

  bool operator <(Rational other) => compareTo(other) < 0;
  bool operator >(Rational other) => compareTo(other) > 0;
  bool operator <=(Rational other) => compareTo(other) <= 0;
  bool operator >=(Rational other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator_ * other.denominator_ == other.numerator_ * denominator_;

  @override
  int get hashCode {
    final r = _reduced();
    return Object.hash(r.$1, r.$2);
  }

  (int, int) _reduced() {
    var n = numerator_, d = denominator_;
    if (n == 0) return (0, 1);
    var g = _gcd(n.abs(), d);
    n ~/= g;
    d ~/= g;
    if (d < 0) {
      n = -n;
      d = -d;
    }
    return (n, d);
  }

  /// 约分后的实例。
  Rational reduced() {
    final (n, d) = _reduced();
    return Rational(n, d);
  }

  double toDouble() => numerator_ / denominator_;

  Map<String, dynamic> toJson() {
    final (n, d) = _reduced();
    return {'n': n, 'd': d};
  }

  @override
  String toString() => '$numerator_/$denominator_';
}

int _gcd(int a, int b) {
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  return a;
}
