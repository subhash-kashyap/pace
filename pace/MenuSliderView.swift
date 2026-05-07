import SwiftUI
import AppKit

// MARK: - MenuSliderView
class MenuSliderView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 0.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let valueLabel = NSTextField(labelWithString: "")
    private let iconImageView = NSImageView()
    
    var onValueChanged: ((Double) -> Void)?
    var valueFormatter: ((Double) -> String)?
    
    init(title: String, iconName: String, value: Double, minValue: Double, maxValue: Double, width: CGFloat = 220) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 32))
        
        // Setup Icon
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            image.isTemplate = true
            iconImageView.image = image
            iconImageView.contentTintColor = .secondaryLabelColor
        }
        iconImageView.frame = NSRect(x: 12, y: 8, width: 16, height: 16)
        addSubview(iconImageView)
        
        // Setup Title
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 36, y: 8, width: 55, height: 16)
        addSubview(titleLabel)
        
        // Setup Slider
        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.doubleValue = value
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.frame = NSRect(x: 95, y: 6, width: 85, height: 20)
        addSubview(slider)
        
        // Setup Value Label
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: 185, y: 8, width: 25, height: 16)
        addSubview(valueLabel)
        
        updateValueLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func sliderChanged(_ sender: NSSlider) {
        updateValueLabel()
        onValueChanged?(sender.doubleValue)
    }
    
    private func updateValueLabel() {
        if let formatter = valueFormatter {
            valueLabel.stringValue = formatter(slider.doubleValue)
        } else {
            valueLabel.stringValue = String(format: "%.1f", slider.doubleValue)
        }
    }
    
    func setValue(_ value: Double) {
        slider.doubleValue = value
        updateValueLabel()
    }
}
