function authorize(...roles) {
  return (req, _res, next) => {
    if (!req.user) return next({ status: 401, message: 'Authentication is required.' });
    if (!roles.includes(req.user.role)) {
      return next({ status: 403, message: 'You do not have permission to perform this action.' });
    }
    return next();
  };
}

module.exports = { authorize };
