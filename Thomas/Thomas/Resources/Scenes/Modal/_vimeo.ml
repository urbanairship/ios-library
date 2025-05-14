---
version: 1
presentation:
  type: modal
  placement_selectors: []
  android:
    disable_back_button: false
  dismiss_on_touch_outside: false
  default_placement:
    ignore_safe_area: false
    size:
      width: 100%
      height: 100%
    position:
      horizontal: center
      vertical: top
    shade_color:
      default:
        type: hex
        hex: "#000000"
        alpha: 0.2
    web: {}
view:
  type: pager_controller
  identifier: 7d97a133-bef8-4c18-b52a-b7a29061768e
  view:
    type: linear_layout
    direction: vertical
    items:
      - size:
          width: 100%
          height: 100%
        view:
          type: container
          items:
            - position:
                horizontal: center
                vertical: center
              size:
                width: 100%
                height: 100%
              view:
                type: pager
                disable_swipe: true
                items:
                  - identifier: 2a35dbf3-1700-4813-8e2c-78747ff4a00c
                    type: pager_item
                    view:
                      type: container
                      items:
                        - size:
                            width: 100%
                            height: 100%
                          position:
                            horizontal: center
                            vertical: center
                          ignore_safe_area: false
                          view:
                            type: container
                            items:
                              - margin:
                                  bottom: 0
                                  top: 0
                                  end: 0
                                  start: 0
                                position:
                                  horizontal: center
                                  vertical: center
                                size:
                                  width: 100%
                                  height: 100%
                                view:
                                  type: linear_layout
                                  direction: vertical
                                  items:
                                    - identifier: scroll_container
                                      size:
                                        width: 100%
                                        height: 100%
                                      view:
                                        type: scroll_layout
                                        direction: vertical
                                        view:
                                          type: linear_layout
                                          direction: vertical
                                          items:
                                            - size:
                                                width: 100%
                                                height: auto
                                              view:
                                                type: media
                                                media_fit: center_inside
                                                url: https://player.vimeo.com/video/714680147?autoplay=0&loop=1&controls=1&muted=1&unmute_button=0
                                                media_type: vimeo
                                                video:
                                                  aspect_ratio: 1.7777777777777777
                                                  autoplay: false
                                                  loop: true
                                                  muted: true
                                                  show_controls: true
                                              identifier: 94c693a7-7392-4ff2-b2d2-fc2d9828bf21
                                              margin:
                                                top: 0
                                                bottom: 0
                                                start: 0
                                                end: 0
                                            - size:
                                                width: 100%
                                                height: 100%
                                              view:
                                                type: linear_layout
                                                direction: horizontal
                                                items: []
                      background_color:
                        default:
                          type: hex
                          hex: "#FFFFFF"
                          alpha: 1
                        selectors:
                          - platform: ios
                            dark_mode: false
                            color:
                              type: hex
                              hex: "#FFFFFF"
                              alpha: 1
                          - platform: ios
                            dark_mode: true
                            color:
                              type: hex
                              hex: "#000000"
                              alpha: 1
                          - platform: android
                            dark_mode: false
                            color:
                              type: hex
                              hex: "#FFFFFF"
                              alpha: 1
                          - platform: android
                            dark_mode: true
                            color:
                              type: hex
                              hex: "#000000"
                              alpha: 1
                          - platform: web
                            dark_mode: false
                            color:
                              type: hex
                              hex: "#FFFFFF"
                              alpha: 1
                          - platform: web
                            dark_mode: true
                            color:
                              type: hex
                              hex: "#000000"
                              alpha: 1
              ignore_safe_area: false
            - position:
                horizontal: end
                vertical: top
              size:
                width: 48
                height: 48
              view:
                type: image_button
                image:
                  scale: 0.4
                  type: icon
                  icon: close
                  color:
                    default:
                      type: hex
                      hex: "#000000"
                      alpha: 1
                    selectors:
                      - platform: ios
                        dark_mode: false
                        color:
                          type: hex
                          hex: "#000000"
                          alpha: 1
                      - platform: ios
                        dark_mode: true
                        color:
                          type: hex
                          hex: "#FFFFFF"
                          alpha: 1
                      - platform: android
                        dark_mode: false
                        color:
                          type: hex
                          hex: "#000000"
                          alpha: 1
                      - platform: android
                        dark_mode: true
                        color:
                          type: hex
                          hex: "#FFFFFF"
                          alpha: 1
                      - platform: web
                        dark_mode: false
                        color:
                          type: hex
                          hex: "#000000"
                          alpha: 1
                      - platform: web
                        dark_mode: true
                        color:
                          type: hex
                          hex: "#FFFFFF"
                          alpha: 1
                identifier: dismiss_button
                button_click:
                  - dismiss
                localized_content_description:
                  ref: ua_dismiss
                  fallback: Dismiss

