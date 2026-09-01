//
//  UIViewController+Extensions.swift
//  CapsizedVault
//
//  Created by Dmitrij on 14/01/2026.
//

import Foundation
import UIKit

extension UIViewController {
    
    func showToast (message: String) {
        let textView = UITextView()
        textView.backgroundColor = UIColor.systemGray5
        textView.textColor = UIColor.label
        textView.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
        textView.textAlignment = .center
        
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.text = message
        
        textView.layer.cornerRadius = 15.0
        textView.textContainerInset = UIEdgeInsets(top: 15.0, left: 15.0, bottom: 10.0, right: 15.0)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.alpha = 0.0
        view.addSubview(textView)
        
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
          textView.topAnchor.constraint(equalToSystemSpacingBelow: guide.topAnchor, multiplier: 1.0),
          textView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
         ])
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.3) {
            textView.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, options: []) {
                textView.alpha = 0.0
            } completion: { _ in
                textView.removeFromSuperview()
            }

        }

    }


}

