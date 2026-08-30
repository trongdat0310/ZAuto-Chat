export function validatePassword(
  password
) {
  if (
    typeof password !==
    "string"
  ) {
    return {
      valid: false,
      error:
        "Mat khau khong hop le.",
    };
  }


  if (password.length < 8) {
    return {
      valid: false,
      error:
        "Mat khau phai co it nhat 8 ky tu.",
    };
  }


  if (!/[A-Z]/.test(password)) {
    return {
      valid: false,
      error:
        "Mat khau phai co it nhat 1 chu hoa.",
    };
  }


  if (!/[a-z]/.test(password)) {
    return {
      valid: false,
      error:
        "Mat khau phai co it nhat 1 chu thuong.",
    };
  }


  if (!/[0-9]/.test(password)) {
    return {
      valid: false,
      error:
        "Mat khau phai co it nhat 1 chu so.",
    };
  }


  // Khoang trang khong duoc tinh
  // la ky tu dac biet.
  if (
    !/[^A-Za-z0-9\s]/.test(
      password
    )
  ) {
    return {
      valid: false,
      error:
        "Mat khau phai co it nhat 1 ky tu dac biet.",
    };
  }


  return {
    valid: true,
    error: null,
  };
}