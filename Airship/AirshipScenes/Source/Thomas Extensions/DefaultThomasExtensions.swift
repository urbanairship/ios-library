/* Copyright Airship and Contributors */

@_spi(AirshipInternal) public import AirshipSceneRenderer
@_spi(AirshipInternal) public import AirshipCore
public import AirshipBasement


/// The Thomas extensions the SDK wires up by default — currently the async-view resolver backed
/// by the real request session. Hosts pass this into the renderer so async views resolve for real.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public struct DefaultThomasExtensions: ThomasExtensions {
    public let asyncViewResolver: (any AsyncViewResolver) = DefaultAsyncViewResolver()
    public let webViewChallengeResolver: (any AirshipWebViewChallengeResolver) = DefaultWebViewChallengeResolver()
    public let localizer: (any ThomasLocalizer) = DefaultThomasLocalizer()
    public let audienceEditor: (any ThomasAudienceEditor) = DefaultThomasAudienceEditor()
    public let imageLoader: any ThomasImageLoader
    public let actionRunner: any ThomasActionRunner
    public let aiInferenceExecutor: (any SceneAIExecutor)?
    public var inputValidator: (any AirshipInputValidation.Validator)? {
        Airship.isFlying ? Airship.inputValidator : nil
    }

#if !os(tvOS) && !os(watchOS)
    public let webViewFactory: any ThomasWebViewFactory

    @_spi(AirshipInternal)
    public init(
        imageProvider: (any AirshipImageProvider)? = nil,
        assetCacheManager: (any AssetCacheManagerProtocol)? = nil,
        actionRunner: (any ThomasActionRunner)? = nil,
        nativeBridgeExtension: (any NativeBridgeExtensionDelegate)? = nil,
        aiManager: (any AirshipAI.InternalManager)? = nil
    ) {
        let actionRunner = actionRunner ?? DefaultThomasActionRunner()
        self.imageLoader = DefaultThomasImageLoader(
            imageProvider: imageProvider,
            assetCacheManager: assetCacheManager
        )
        self.actionRunner = actionRunner
        self.webViewFactory = DefaultThomasWebViewFactory(
            actionRunner: actionRunner,
            nativeBridgeExtension: nativeBridgeExtension
        )
        self.aiInferenceExecutor = aiManager.map {
            DefaultSceneAIExecutor(aiManager: $0)
        }
    }
#else
    @_spi(AirshipInternal)
    public init(
        imageProvider: (any AirshipImageProvider)? = nil,
        assetCacheManager: (any AssetCacheManagerProtocol)? = nil,
        actionRunner: (any ThomasActionRunner)? = nil,
        aiManager: (any AirshipAI.InternalManager)? = nil
    ) {
        self.imageLoader = DefaultThomasImageLoader(
            imageProvider: imageProvider,
            assetCacheManager: assetCacheManager
        )
        self.actionRunner = actionRunner ?? DefaultThomasActionRunner()
        self.aiInferenceExecutor = aiManager.map {
            DefaultSceneAIExecutor(aiManager: $0)
        }
    }
#endif
}
