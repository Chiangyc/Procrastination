// procrastinationApp.swift
import SwiftUI
import FirebaseCore
import Supabase
import Combine

@main
struct procrastinationApp: App {
    // 這兩個現在要用「延後初始化」的寫法，因為 AuthViewModel 需要 store
    @StateObject private var store: AppStore
    @StateObject private var authVM: AuthViewModel
    @State private var geminiService: GeminiService

    init() {
        FirebaseApp.configure()

        // 先建立 AppStore
        let appStore = AppStore()
        _store = StateObject(wrappedValue: appStore)

        // 再把同一個 appStore 傳給 AuthViewModel
        _authVM = StateObject(wrappedValue: AuthViewModel(store: appStore))

        // GeminiService 一樣
        _geminiService = State(initialValue: GeminiService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(authVM)
                .environment(geminiService)
                .environment(\.locale, .init(identifier: store.language.rawValue))
                .task {
                    // ✅ App 啟動後，嘗試從 Supabase 恢復 session
                    await authVM.restoreSessionOnLaunch()
                }
                .onAppear {
                    // 只做本機通知授權，不再自動登入 Dev 帳號、也不自動 push 資料
                    NotificationManager.requestAuthorization()
                }
        }
    }
}
