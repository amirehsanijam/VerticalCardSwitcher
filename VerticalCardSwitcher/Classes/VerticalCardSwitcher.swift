//
//  VerticalCardSwitcher.swift
//  Pods
//
//  Created by Matija Kruljac on 5/19/17.
//  Copyright © 2017 Matija Kruljac. All rights reserved.
//

import Foundation
import UIKit

public class VerticalCardSwitcher: NSObject {
    
    public weak var delegate: VerticalCardSwitcherDelegate?
    
    private var cards = [CardView]()
    private var viewControllerView: UIView!
    
    private var yOriginCurrentCard: CGFloat!
    private var xOriginCurrentCard: CGFloat!
    
    private var currentCardFrame = CGRect.zero
    private var nextCardFrame = CGRect.zero
    
    private var upperBorder: CGFloat!
    private var bottomBorder: CGFloat!
    
    private let initialNumberOfAddedCardsToSuperView = 3
    
    public init(in viewControllerView: UIView) {
        super.init()
        self.viewControllerView = viewControllerView
    }
    
    public func display() {
        setupMarginsAndInitialFrames()
        guard let delegate = delegate else { return }
        var yOriginNextCard: CGFloat = yOriginCurrentCard
        
        for index in 0...delegate.numberOfCards(for: self) - 1 {
            let cardFrame = CGRect(
                x: xOriginCurrentCard,
                y: yOriginNextCard,
                width: viewControllerView.frame.size.width - 2*xOriginCurrentCard,
                height: delegate.heightForCardView(in: self))
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
            panGestureRecognizer.minimumNumberOfTouches = 1
            panGestureRecognizer.maximumNumberOfTouches = 1
            
            let cardView = CardView.init(frame: cardFrame, with: index, andWith: panGestureRecognizer)
            delegate.addDesign(for: cardView, at: index, in: self)
            cardView.setupBlurView()
            
            cards.append(cardView)
            
            if index < initialNumberOfAddedCardsToSuperView {
                viewControllerView.addSubview(cardView)
            }
            yOriginNextCard += currentCardFrame.size.height + delegate.distanceBetweenCards(for: self)
        }
    }
    
    private func setupMarginsAndInitialFrames() {
        guard let delegate = delegate else { return }
        self.xOriginCurrentCard = viewControllerView.frame.origin.x + delegate.sideMargins(for: self)
        self.yOriginCurrentCard = viewControllerView.frame.size.height -
            ((1+delegate.heightOfShowedPartForEveryNextCard(in: self))*delegate.heightForCardView(in: self) +
                delegate.distanceBetweenCards(for: self))
        self.setupInitialFrames()
        self.upperBorder = yOriginCurrentCard + 0.2*currentCardFrame.size.height
        self.bottomBorder = yOriginCurrentCard + 0.8*currentCardFrame.size.height
    }
    
    private func setupInitialFrames() {
        guard let delegate = delegate else { return }
        currentCardFrame = CGRect(
            x: xOriginCurrentCard,
            y: yOriginCurrentCard,
            width: viewControllerView.frame.size.width - 2*xOriginCurrentCard,
            height: delegate.heightForCardView(in: self))
        
        nextCardFrame = CGRect(
            x: xOriginCurrentCard,
            y: yOriginCurrentCard + currentCardFrame.size.height + delegate.distanceBetweenCards(for: self),
            width: viewControllerView.frame.size.width - 2*xOriginCurrentCard,
            height: delegate.heightForCardView(in: self))
    }
    
    @objc private func handlePanGesture(panGestureRecognizer: UIPanGestureRecognizer) {
        guard let cardView = panGestureRecognizer.view as? CardView else { return }
        viewControllerView.bringSubview(toFront: cardView)
        let velocity = panGestureRecognizer.velocity(in: viewControllerView)
        
        if foundedUndesiredState(for: cardView, with: velocity) {
            setupNewFrameForCardViewAndMakeItCurrent(panGestureRecognizer: panGestureRecognizer, with: cardView)
            resetFrameAndAnimateWhenPanGestureIsEnded(panGestureRecognizer: panGestureRecognizer, with: cardView)
            shouldEnableNeighbouringCardViewsPanGesture(for: cardView, true)
            return
        }
        
        if panGestureRecognizer.state == .began || panGestureRecognizer.state == .changed {
            shouldEnableNeighbouringCardViewsPanGesture(for: cardView, false)
            let translation = panGestureRecognizer.translation(in: viewControllerView)
            cardView.center = CGPoint(x: cardView.center.x, y: cardView.center.y + translation.y)
            makeScaleDepthEffect(with: panGestureRecognizer, for: cardView)
            panGestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: viewControllerView)
        }
        
        if panGestureRecognizer.state == .ended {
            setupNewFrameForCardViewAndMakeItCurrent(panGestureRecognizer: panGestureRecognizer, with: cardView)
            resetFrameAndAnimateWhenPanGestureIsEnded(panGestureRecognizer: panGestureRecognizer, with: cardView)
            shouldEnableNeighbouringCardViewsPanGesture(for: cardView, true)
            handleDelegateWhenEndedScrolling(with: panGestureRecognizer, for: cardView)
        }
    }
    
    private func foundedUndesiredState(for cardView: CardView, with velocity: CGPoint) -> Bool {
        // undesired state
        if cardView.frame.origin.y <= yOriginCurrentCard && velocity.y <= 0 {
            return true
        }
        // undesired state
        if cardView.indexInCollection == 0 {
            return true
        }
        return false
    }
    
    private func makeScaleDepthEffect(with panGestureRecognizer: UIPanGestureRecognizer, for cardView: CardView) {
        // scale - depth effect
        switch panGestureRecognizer.determineVerticalDirection(for: cardView) {
        case .up:
            scaleCardViewAndChangeAlphaOfBlurView(cardView, withFactor: 0.85)
        case .down:
            scaleCardViewAndChangeAlphaOfBlurView(cardView, withFactor: 1.0)
        }
    }
    
    private func handleDelegateWhenEndedScrolling(with panGestureRecognizer: UIPanGestureRecognizer, for cardView: CardView) {
        let panDirection: UIPanGestureRecognizer.PanDirection = panGestureRecognizer.determineVerticalDirection(for: cardView)
        if cardView.frame.origin.y < bottomBorder && panDirection == .up {
            delegate?.nextCardScrolledUp?(cardView: cardView, for: self)
        }
        if cardView.frame.origin.y >= upperBorder {
            delegate?.currentCardScrolledDown?(cardView: cardView, for: self)
        }
    }
    
    private func changeAnimatedNextCardFrame(for cardView: CardView) {
        if #available(iOS 10.0, *) {
            let viewAnimator = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut, animations: { [weak self] _ in
                guard let sSelf = self else { return }
                cardView.frame = sSelf.nextCardFrame
            })
            viewAnimator.startAnimation()
        } else {
            // Fallback on earlier versions
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: { [weak self] _ in
                guard let sSelf = self else { return }
                cardView.frame = sSelf.nextCardFrame
            }, completion: nil)
        }
    }
    
    private func changeAnimatedCurrentCardFrame(for cardView: CardView) {
        if #available(iOS 10.0, *) {
            let viewAnimator = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut, animations: { [weak self] _ in
                guard let sSelf = self else { return }
                cardView.frame = sSelf.currentCardFrame
            })
            viewAnimator.startAnimation()
        } else {
            // Fallback on earlier versions
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: { [weak self] _ in
                guard let sSelf = self else { return }
                cardView.frame = sSelf.currentCardFrame
            }, completion: nil)
        }
    }
    
    private func setupNewFrameForCardViewAndMakeItCurrent(panGestureRecognizer: UIPanGestureRecognizer, with cardView: CardView) {
        let panDirection: UIPanGestureRecognizer.PanDirection = panGestureRecognizer.determineVerticalDirection(for: cardView)
        if  cardView.frame.origin.y < bottomBorder && panDirection == .up {
            addAndRemoveNeighbouringCardViewsOnScrollUp(forCurrentView: cardView.indexInCollection)
            changeAnimatedCurrentCardFrame(for: cardView)
            setupFrameForNextCardView(after: cardView)
        }
        if cardView.frame.origin.y >= upperBorder && cardView.indexInCollection > 0 {
            addAndRemoveNeighbouringCardViewsOnScrollDown(forCurrentView: cardView.indexInCollection)
            changeAnimatedNextCardFrame(for: cardView)
        }
    }
    
    private func resetFrameAndAnimateWhenPanGestureIsEnded(panGestureRecognizer: UIPanGestureRecognizer, with cardView: CardView) {
        if cardView.frame.origin.y >= upperBorder && cardView.indexInCollection > 0 {
            changeAnimatedNextCardFrame(for: cardView)
            scaleCardViewAndChangeAlphaOfBlurView(cardView, withFactor: 1.0)
        }
        if cardView.frame.origin.y < bottomBorder {
            changeAnimatedCurrentCardFrame(for: cardView)
            scaleCardViewAndChangeAlphaOfBlurView(cardView, withFactor: 0.85)
        }
        viewControllerView.bringSubview(toFront: panGestureRecognizer.view!)
    }
    
    private func setupFrameForNextCardView(after cardView: CardView) {
        if cardView.indexInCollection > 0 && cardView.indexInCollection + 1 < cards.count {
            let nextCardView = cards[cardView.indexInCollection + 1]
            nextCardView.frame = nextCardFrame
        }
    }
    
    private func scaleCardViewAndChangeAlphaOfBlurView(_ cardView: CardView, withFactor factor: CGFloat) {
        if cardView.indexInCollection > 0 {
            if #available(iOS 10.0, *) {
                let viewAnimator = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut, animations: { [weak self] _ in
                    guard let sSelf = self else { return }
                    let previousCardView = sSelf.cards[cardView.indexInCollection - 1]
                    if factor == 0.85 {
                        previousCardView.blurEffectView.alpha = 0.7
                    } else {
                        previousCardView.blurEffectView.alpha = 0.0
                    }
                    previousCardView.transform = CGAffineTransform(scaleX: factor, y: factor)
                })
                viewAnimator.startAnimation()
            } else {
                // Fallback on earlier versions
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: { [weak self] _ in
                    guard let sSelf = self else { return }
                    let previousCardView = sSelf.cards[cardView.indexInCollection - 1]
                    if factor == 0.85 {
                        previousCardView.blurEffectView.alpha = 0.7
                    } else {
                        previousCardView.blurEffectView.alpha = 0.0
                    }
                    previousCardView.transform = CGAffineTransform(scaleX: factor, y: factor)
                }, completion: nil)
            }
        }
    }
    
    private func addAndRemoveNeighbouringCardViewsOnScrollUp(forCurrentView index: Int) {
        if index >= 2 && index < cards.count - 1 {
            let belowCurrentCardView = cards[index - 2]
            belowCurrentCardView.removeFromSuperview()
            
            let nextCardView = cards[index + 1]
            viewControllerView.addSubview(nextCardView)
        }
    }
    
    private func addAndRemoveNeighbouringCardViewsOnScrollDown(forCurrentView index: Int) {
        if index >= 2 && index < cards.count - 1 {
            let currentCardView = cards[index - 1]
            let belowCurrentCardView = cards[index - 2]
            viewControllerView.addSubview(belowCurrentCardView)
            viewControllerView.bringSubview(toFront: currentCardView)
            
            let nextCardView = cards[index + 1]
            nextCardView.removeFromSuperview()
        }
    }
    
    private func shouldEnableNeighbouringCardViewsPanGesture(for cardView: CardView, _ isEnabled: Bool) {
        if cardView.indexInCollection > 0 {
            let previousCardView = cards[cardView.indexInCollection - 1]
            previousCardView.panGestureRecognizer.isEnabled = isEnabled
        }
        if cardView.indexInCollection < cards.count - 1 {
            let nextCardView = cards[cardView.indexInCollection + 1]
            nextCardView.panGestureRecognizer.isEnabled = isEnabled
        }
    }
}
