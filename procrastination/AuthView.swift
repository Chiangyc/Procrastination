import SwiftUI

struct AuthView: View {
    enum Mode { case login, register }

    @EnvironmentObject var authVM: AuthViewModel
    // ✅ 1. 新增這個：我們需要存取 store 才能切換語言
    @EnvironmentObject var store: AppStore
    
    @State private var mode: Mode = .login

    var body: some View {
        VStack(spacing: 20) {
            
            // ✅ 2. 新增語言切換按鈕 (放在最上面)
            HStack {
                Spacer()
                Menu {
                    Picker("Language", selection: $store.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text(store.language.displayName)
                    }
                    .font(.subheadline)
                    .padding(8)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
                }
            }
            .padding(.bottom, 20) // 拉開一點距離
            
            Spacer()

            // ✅ 3. 修改標題：改成英文 Key
            Text(mode == .login ? "Log In" : "Sign Up")
                .font(.largeTitle)
                .bold()

            // ✅ 4. 修改欄位提示：改成英文 Key
            TextField("Email", text: $authVM.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            if mode == .register {
                TextField("Display Name", text: $authVM.displayName) // 原本是 "用戶名稱"
                    .textFieldStyle(.roundedBorder)
            }

            SecureField("Password", text: $authVM.password) // 原本是 "密碼"
                .textFieldStyle(.roundedBorder)

            // ✅ 5. 修改按鈕文字
            Button(mode == .login ? "Log In" : "Sign Up") {
                Task {
                    if mode == .login {
                        await authVM.login()
                    } else {
                        await authVM.register()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authVM.isLoading)

            // 錯誤訊息 (如果是後端回傳的英文錯誤，這裡可能需要另外處理翻譯，暫時不動)
            if let msg = authVM.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            // ✅ 6. 修改切換模式文字
            Button(mode == .login ? "No account? Sign up" : "Have an account? Log in") {
                mode = (mode == .login) ? .register : .login
            }
            .font(.footnote)

            // 成功登入後顯示暫時提示
            if let user = authVM.currentUser {
                // 這句我們之前翻過了，保持原樣即可 (Hi, %@)
                Text("Hi, \(user.displayName ?? "User")")
                    .font(.title3)
                    .padding(.top)
            }
            
            Spacer() // 推到上面去，版面比較好看
        }
        .padding()
    }
}
