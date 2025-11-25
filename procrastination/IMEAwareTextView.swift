import SwiftUI

struct IMEAwareTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var onCommit: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.returnKeyType = .send             // 鍵盤右下角顯示「送出」
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // 加一層 placeholder label
        let ph = UILabel()
        ph.text = placeholder
        ph.textColor = UIColor.secondaryLabel.withAlphaComponent(0.6)
        ph.font = tv.font
        ph.numberOfLines = 1
        ph.tag = 999
        ph.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 12),
            ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: 8)
        ])
        ph.isHidden = !text.isEmpty

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // 切換 placeholder 顯示
        if let ph = uiView.viewWithTag(999) as? UILabel {
            ph.isHidden = !text.isEmpty
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: IMEAwareTextView
        init(_ parent: IMEAwareTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            if let ph = textView.viewWithTag(999) as? UILabel {
                ph.isHidden = !parent.text.isEmpty
            }
        }

        // 核心：判斷 Enter
        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            // 只攔截換行鍵
            if text == "\n" {
                // 如果還在「組字」狀態，就讓輸入法處理（回傳 true）
                if textView.markedTextRange != nil {
                    return true
                }
                // 非組字：當成送出，呼叫 onCommit，並阻止插入換行（回傳 false）
                parent.onCommit()
                return false
            }
            return true
        }
    }
}
