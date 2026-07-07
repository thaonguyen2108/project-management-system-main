import 'package:flutter/material.dart';
import 'package:todo/controllers/account_Controller.dart';
import 'package:todo/core/navigation.dart';
import 'package:todo/widgets/ui.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final accController = AccountController();

  bool isHidden = true;
  double sizeChuan = 14;
  String logo = "assets/images/logo.png";

  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passController = TextEditingController();


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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    image(
                      logo,
                      width: MediaQuery.of(context).size.width / 3.2,
                      height: MediaQuery.of(context).size.width / 3.2,
                      radius: BorderRadius.circular(12)
                    ),

                    box(height: 5),

                    text(
                      "Quản lý công việc hiệu quả",
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
                                "Đăng nhập",
                                align: TextAlign.left,
                                size: sizeChuan * 1.5,
                                weight: FontWeight.bold,

                              ),

                              box(height: 30),

                              formInput(
                                controller: emailController,
                                label: "Email",
                                hint: "yourmail@gmail.com",
                                prefixIcon: Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                labelColor: const Color.fromARGB(255, 16, 47, 200),
                                labelFontWeight: FontWeight.normal,
                                // Bắt lỗi nếu để trống hoặc không đúng định dạng
                                validator: (value) {
                                  if (value == null || value.isEmpty) return "Email không được để trống!";
                                  if (!value.contains("@")) return "Email không hợp lệ!";
                                  return null;
                                },
                              ),

                              box(height: 20),

                              formInput(
                                controller: passController,
                                label: "Mật khẩu",
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
                                labelColor: const Color.fromARGB(255, 16, 47, 200),
                                // Bắt lỗi nếu để trống hoặc không đúng định dạng
                                validator: (value) {
                                  if (value == null || value.isEmpty) return "Vui lòng nhập mật khẩu!";
                                  return null;
                                },
                              ),

                              align(
                                child: textButton(
                                  label: "Quên mật khẩu?", 
                                  onPressed: () {
                                    if (emailController.text.trim().isEmpty) {
                                      if (!context.mounted) return;
                                      snack(
                                        context, 
                                        message: "Vui lòng nhập email để nhận link reset mật khẩu.", 
                                        backgroundColor: const Color.fromARGB(255, 136, 9, 0)
                                      );
                                      return;
                                    }

                                    accController.resetPassword(emailController.text.trim());

                                    if (!context.mounted) return;
                                    snack(
                                      context, 
                                      message: "Nếu email tồn tại, một link reset mật khẩu đã được gửi. Vui lòng kiểm tra hộp thư của bạn.", 
                                      backgroundColor: Colors.indigo,
                                      duration: Duration(seconds: 5),
                                    );                                    
                                  }, 
                                  color: const Color.fromARGB(255, 27, 59, 200)
                                ),
                                alignment: Alignment.topRight,
                              ),

                              box(height: 10),

                              align(
                                child: button(
                                  label: "Đăng nhập", 
                                  onPressed: () async {

                                    if (_formKey.currentState?.validate() ?? false){

                                      final result = await accController.signInWithEmail(
                                        email: emailController.text.trim(), 
                                        password: passController.text.trim()
                                      );

                                      if (result == null) {
                                        if (!context.mounted) return;
                                        snack(
                                          context, 
                                          message: "Sign in failed. Please check your credentials and try again.", 
                                          backgroundColor: const Color.fromARGB(255, 136, 9, 0)
                                        );
                                        accController.signOut();
                                        return;
                                      }

                                      final user = result.user;

                                      //reload để lấy trạng thái mới nhất
                                      await user?.reload();

                                      final updatedUser = FirebaseAuth.instance.currentUser;

                                      if (updatedUser != null && !updatedUser.emailVerified) {
                                        // 👉 show dialog
                                        if (!context.mounted) return;

                                        dialog(
                                          context, 
                                          title: "Xác thực email", 
                                          message: "Vui lòng kiểm tra email để xác thực tài khoản. Nếu bạn chưa nhận được email, hãy nhấn gửi lại.",
                                          okText: "Gửi lại",
                                          onOk: () {
                                            accController.sendVerifyEmail();

                                            snack(
                                              context, 
                                              message: "Email xác thực đã được gửi lại. Vui lòng kiểm tra hộp thư của bạn.", 
                                              backgroundColor: Colors.indigo,
                                              duration: Duration(seconds: 5),
                                            );
                                          },
                                        );
                                        accController.signOut();

                                        return;
                                      }

                                      if (!context.mounted) return;
                                      snack(
                                        context, 
                                        message: " Đăng nhập thành công!", 
                                        backgroundColor: const Color.fromARGB(255, 40, 151, 236),
                                        textColor: Colors.black
                                      );

                                      print("Đăng nhập thành công: ${user?.email} - uid: ${user?.uid} - displayName: ${user?.displayName}");                                    
                                    }

                                  },
                                  width: double.infinity,
                                  color: const Color.fromARGB(255, 0, 27, 205),
                                  textColor: Colors.white,
                                ),
                                alignment: Alignment.center,
                              ),

                              box(height: 20),

                              align(
                                child: row(
                                  children: [
                                    flexible(
                                      child: box(
                                        child: hDivider(color: Colors.black),
                                      ),
                                    ),

                                    box(width: 10),

                                    text("Hoặc đăng nhập với"),

                                    box(width: 10),

                                    flexible(
                                      child: box(
                                        child: hDivider(color: Colors.black),
                                      ),
                                    ),

                                  ]
                                ),
                              ),

                              box(height: 10),

                              align(
                                alignment: Alignment.center,
                                child: row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    pressable(
                                      child: avatar(
                                        child: image(
                                          "assets/images/google-logo.png",
                                        ),
                                      ),
                                      onTap: () async{
                                        print("  Đăng nhập với Google");

                                        final result = await accController.signInWithGoogle();
                                        if (result == null) {
                                          print("#############################################################################################################");
                                        }


                                        if (result != null) {
                                          if (!context.mounted) return;
                                          snack(
                                            context, 
                                            message: " Đăng nhập thành công với Google!", 
                                            backgroundColor: const Color.fromARGB(255, 40, 151, 236),
                                            textColor: Colors.black
                                          );
                                          print("Đăng nhập thành công: ${result.user?.email} - uid: ${result.user?.photoURL}");

                                          // if (!context.mounted) return;
                                          // AppNav.goToHome(context);
                                          
                                        } 
                                        else {
                                          print("Đăng nhập thất bại");
                                        }
                                      },

                                    ),

                                  ],
                                ),
                              ),

                              align(
                                child: row(
                                  children: [
                                    text("Bạn chưa có tài khoản?"),
                                    textButton(
                                      label: "Đăng ký ngay", 
                                      onPressed: () {
                                        AppNav.goToRegister(context);
                                      },
                                      color: const Color.fromARGB(255, 40, 67, 243),
                                    )
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
                      ),// containerBox

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

                    text(
                      "Team A4 - Thanks for using ♥️",
                      color: Colors.white,
                    )

                  ],
                  
                ),
              ),
            ),
          )
        ]
      )
    );
  }
}
