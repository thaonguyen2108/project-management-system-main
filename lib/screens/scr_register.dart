import 'package:flutter/material.dart';
import 'package:todo/core/navigation.dart';
import 'package:todo/widgets/ui.dart';
import 'package:todo/controllers/account_Controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool isHidden = true;
  bool isRegistering = false;
  double sizeChuan = 14;
  String logo = "assets/images/logo.png";
  final accController = AccountController();

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final emailVerificationController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    emailVerificationController.dispose();
    passController.dispose();
    confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      backgroundColor: const Color.fromARGB(255, 40, 67, 126),
      body: stack(
        children: [
          image(
            "assets/images/hinh_nen_1.jpg",
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),

          containerBox(
            width: double.infinity,
            height: double.infinity,
            color: const Color.fromARGB(102, 0, 0, 0),
          ),

          align(
            alignment: Alignment.center,
            child: scroll(
              child: align(
                alignment: Alignment.center,
                child: column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    image(
                      logo,
                      width: MediaQuery.of(context).size.width / 3.2,
                      height: MediaQuery.of(context).size.width / 3.2,
                      radius: BorderRadius.circular(12),
                    ),

                    box(height: 5),

                    text(
                      "Chào mừng đến với ToDo",
                      align: TextAlign.center,
                      weight: FontWeight.w100,
                      size: sizeChuan,
                      color: Colors.white,
                    ),

                    box(height: 30),

                    containerBox(
                      child: padding(
                        child: Form(
                          key: _formKey,
                          child: column(
                            children: [
                              text(
                                "Đăng ký",
                                align: TextAlign.left,
                                size: sizeChuan * 1.5,
                                weight: FontWeight.bold,
                              ),

                              box(height: 30),

                              formInput(
                                controller: nameController,
                                label: "Họ & tên",
                                hint: "Nguyễn Văn A",
                                prefixIcon: Icons.person,
                                keyboard: TextInputType.name,
                                labelColor: const Color.fromARGB(
                                  255,
                                  16,
                                  47,
                                  200,
                                ),
                                labelFontWeight: FontWeight.normal,
                                // Bắt lỗi nếu để trống hoặc không đúng định dạng
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return "Họ tên không được để trống!";
                                  return null;
                                },
                              ),

                              box(height: 20),

                              formInput(
                                controller: emailController,
                                label: "Email",
                                hint: "yourmail@gmail.com",
                                prefixIcon: Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                labelColor: const Color.fromARGB(
                                  255,
                                  16,
                                  47,
                                  200,
                                ),
                                labelFontWeight: FontWeight.normal,
                                // Bắt lỗi nếu để trống hoặc không đúng định dạng
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return "Email không được để trống!";
                                  if (!value.contains("@"))
                                    return "Email không hợp lệ!";
                                  return null;
                                },
                              ),

                              box(height: 20),

                              // row(
                              //   children: [
                              //     flexible(
                              //       child: formInput(
                              //         controller: emailVerificationController,
                              //         label: "Xác thực Email",
                              //         hint: "123456",
                              //         prefixIcon: Icons.key,
                              //         keyboard: TextInputType.number,
                              //         labelColor: const Color.fromARGB(255, 16, 47, 200),
                              //         labelFontWeight: FontWeight.normal,
                              //         // Bắt lỗi nếu để trống hoặc không đúng định dạng
                              //         validator: (value) {
                              //           if (value == null || value.isEmpty) return "Email không được để trống!";
                              //           if (!value.contains("@")) return "Email không hợp lệ!";
                              //           return null;
                              //         },
                              //       ),
                              //       flex: 2,
                              //     ),

                              //     box(width: 10),

                              //     flexible(
                              //       child: button(
                              //         label: "Lấy mã",
                              //         onPressed: () {},
                              //         width: double.infinity,
                              //         color: const Color.fromARGB(255, 158, 188, 237),
                              //         textColor: const Color.fromARGB(255, 0, 0, 0),
                              //       ),
                              //     )
                              //   ]
                              // ),

                              // box(height: 20),
                              formInput(
                                controller: passController,
                                label: "Mật khẩu",
                                hint: "Nhập mật khẩu",
                                isPassword: isHidden,
                                prefixIcon: Icons.lock,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isHidden
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isHidden = !isHidden;
                                    });
                                  },
                                ),
                                keyboard: TextInputType.text,
                                labelColor: const Color.fromARGB(
                                  255,
                                  16,
                                  47,
                                  200,
                                ),
                                // Bắt lỗi nếu để trống hoặc không đúng định dạng
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Mật khẩu không được để trống!";
                                  }

                                  if (value.length < 8) {
                                    return "Mật khẩu phải ít nhất 8 ký tự!";
                                  }

                                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                    return "Phải có ít nhất 1 chữ hoa!";
                                  }

                                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                                    return "Phải có ít nhất 1 chữ thường!";
                                  }

                                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                                    return "Phải có ít nhất 1 số!";
                                  }

                                  if (!RegExp(
                                    r'[!@#\$&*~%^()_\-+=<>?]',
                                  ).hasMatch(value)) {
                                    return "Phải có ký tự đặc biệt!";
                                  }

                                  return null;
                                },
                              ),

                              box(height: 20),

                              formInput(
                                controller: confirmPassController,
                                label: "Xác nhận mật khẩu",
                                hint: "Abcd@1234",
                                isPassword: isHidden,
                                prefixIcon: Icons.lock,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isHidden
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isHidden = !isHidden;
                                    });
                                  },
                                ),
                                keyboard: TextInputType.text,
                                labelColor: const Color.fromARGB(
                                  255,
                                  16,
                                  47,
                                  200,
                                ),
                                // Bắt lỗi nếu để trống hoặc không đúng định dạng
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Không được để trống!";
                                  }
                                  if (value.trim() !=
                                      passController.text.trim()) {
                                    return "Mật khẩu xác nhận không khớp!";
                                  }
                                  return null;
                                },
                              ),

                              box(height: 20),

                              align(
                                child: button(
                                  label: "Đăng ký",
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      if (isRegistering) return;

                                      setState(() {
                                        isRegistering = true;
                                      });

                                      final credential = await accController
                                          .registerWithEmail(
                                            email: emailController.text.trim(),
                                            password: passController.text
                                                .trim(),
                                            name: nameController.text.trim(),
                                          );
                                      if (!context.mounted) return;

                                      setState(() {
                                        isRegistering = false;
                                      });

                                      if (credential == null) {
                                        snack(
                                          context,
                                          message:
                                              "Dang ky that bai. Vui long thu lai.",
                                          backgroundColor: const Color.fromARGB(
                                            255,
                                            136,
                                            9,
                                            0,
                                          ),
                                        );
                                        return;
                                      }
                                      final user =
                                          credential.user ??
                                          FirebaseAuth.instance.currentUser;
                                      print(
                                        "Đăng ký thành công: ${user?.email} - uid: ${user?.uid} - displayName: ${user?.displayName}",
                                      );
                                      snack(
                                        context,
                                        message:
                                            "Vui lòng kiểm tra email để xác thực tài khoản trước khi đăng nhập!",
                                        backgroundColor: Colors.indigo,
                                        duration: Duration(seconds: 5),
                                      );
                                      await accController.signOut();
                                      if (!context.mounted) return;
                                      AppNav.goToLogin(context);
                                    } else {
                                      print(
                                        "Form chưa hợp lệ, xem lại các lỗi hiển thị trên form nhé!",
                                      );
                                    }
                                  },
                                  width: double.infinity,
                                  color: const Color.fromARGB(255, 0, 27, 205),
                                  textColor: Colors.white,
                                ),
                                alignment: Alignment.center,
                              ),

                              box(height: 30),

                              align(
                                child: row(
                                  children: [
                                    text("Bạn đã có tài khoản?"),
                                    textButton(
                                      label: "Đăng nhập ngay",
                                      onPressed: () {
                                        AppNav.goToLogin(context);
                                      },
                                      color: const Color.fromARGB(
                                        255,
                                        40,
                                        67,
                                        243,
                                      ),
                                    ),
                                  ],
                                  mainAxisAlignment: MainAxisAlignment.center,
                                ),
                                alignment: Alignment.center,
                              ),
                            ],
                            crossAxisAlignment: CrossAxisAlignment.start,
                          ), // column
                        ),
                        top: 25,
                        bottom: 10,
                        left: 20,
                        right: 20,
                      ), // padding
                      width: double.infinity,
                      // height: 500,
                      margin: EdgeInsets.symmetric(horizontal: 10),
                      color: const Color.fromARGB(182, 194, 205, 237),
                      radius: BorderRadius.circular(12),
                      blur: 5,
                      // shadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withOpacity(0.5), //pha màu bóng
                      //     blurRadius: 10, //độ nhạt của bóng
                      //     offset: Offset(10, 10) //hướng đổ bóng
                      //   )
                      // ]
                    ),

                    box(height: 20),

                    text("Team A4 - Thanks for using ♥️", color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
