// Brent's method (Brent-Dekker; Press et al., Numerical Recipes §9.3):
// root of [g] bracketed in [a,b] (requires g(a) and g(b) to have opposite
// sign, or either exactly zero). Combines inverse-quadratic/secant
// interpolation with a bisection fallback -- the bracket is guaranteed to
// shrink every iteration (bisection's basic guarantee), so convergence is
// provable regardless of the function's shape, while the interpolation
// steps make it converge much faster than bisection alone in practice. No
// derivative required.
double brentRoot(
  double Function(double) g,
  double a,
  double b, {
  double tol = 1e-13,
  int maxIter = 100,
}) {
  const eps = 2.220446049250313e-16; // machine epsilon for double
  var fa = g(a), fb = g(b);
  if (fa == 0.0) return a;
  if (fb == 0.0) return b;
  var c = a, fc = fa;
  var d = b - a, e = d;
  for (int iter = 0; iter < maxIter; iter++) {
    if ((fb > 0) == (fc > 0)) {
      c = a;
      fc = fa;
      d = b - a;
      e = d;
    }
    if (fc.abs() < fb.abs()) {
      a = b;
      b = c;
      c = a;
      fa = fb;
      fb = fc;
      fc = fa;
    }
    final tol1 = 2 * eps * b.abs() + 0.5 * tol;
    final xm = 0.5 * (c - b);
    if (xm.abs() <= tol1 || fb == 0.0) return b;
    if (e.abs() >= tol1 && fa.abs() > fb.abs()) {
      final s = fb / fa;
      double p, q;
      if (a == c) {
        p = 2 * xm * s;
        q = 1 - s;
      } else {
        final qq = fa / fc, r = fb / fc;
        p = s * (2 * xm * qq * (qq - r) - (b - a) * (r - 1));
        q = (qq - 1) * (r - 1) * (s - 1);
      }
      if (p > 0) q = -q;
      p = p.abs();
      final min1 = 3 * xm * q - (tol1 * q).abs();
      final min2 = (e * q).abs();
      if (2 * p < (min1 < min2 ? min1 : min2)) {
        e = d;
        d = p / q;
      } else {
        d = xm;
        e = d;
      }
    } else {
      d = xm;
      e = d;
    }
    a = b;
    fa = fb;
    if (d.abs() > tol1) {
      b += d;
    } else {
      b += xm.isNegative ? -tol1 : tol1;
    }
    fb = g(b);
  }
  return b;
}
