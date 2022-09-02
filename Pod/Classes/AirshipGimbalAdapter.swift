/* Copyright Airship and Contributors */

import AirshipKit

#if !targetEnvironment(simulator)
import Gimbal
#endif

// Keys
fileprivate let hideBlueToothAlertViewKey = "gmbl_hide_bt_power_alert_view"
fileprivate let shouldTrackCustomEntryEventsKey = "gmbl_should_track_custom_entry"
fileprivate let shouldTrackCustomExitEventsKey = "gmbl_should_track_custom_exit"
fileprivate let shouldTrackRegionEventsKey = "gmbl_should_track_region_events"

@objc open class AirshipGimbalAdapter : NSObject {

    /**
     * Singleton access.
     */
    @objc public static let shared = AirshipGimbalAdapter()

    #if !targetEnvironment(simulator)

    /**
     * Receives forwarded callbacks from the PlaceManagerDelegate
     */
    @objc open var delegate: PlaceManagerDelegate?

    private let placeManager: PlaceManager
    private let gimbalDelegate: AirshipGimbalDelegate
    private let deviceAttributesManager: DeviceAttributesManager
    
    #endif
    
    /**
     * Returns true if the adapter is started, otherwise false.
     */
    @objc open var isStarted: Bool {
        get {
            #if !targetEnvironment(simulator)
            return Gimbal.isStarted()
            #else
            return false
            #endif
        }
    }
  

    /**
     * Enables alert when Bluetooth is powered off. Defaults to NO.
     */
    @objc open var bluetoothPoweredOffAlertEnabled : Bool {
        get {
            return !UserDefaults.standard.bool(forKey: hideBlueToothAlertViewKey)
        }
        set {
            UserDefaults.standard.set(!newValue, forKey: hideBlueToothAlertViewKey)
        }
    }
    
    /**
     * Enables creation of UrbanAirship CustomEvents when Gimbal place entries are detected.
     */
    @objc open var shouldTrackCustomEntryEvents : Bool {
        get {
            return UserDefaults.standard.bool(forKey: shouldTrackCustomEntryEventsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: shouldTrackCustomEntryEventsKey)
        }
    }
    
    /**
     * Enables creation of UrbanAirship CustomEvents when Gimbal place exits are detected.
     */
    @objc open var shouldTrackCustomExitEvents : Bool {
        get {
            return UserDefaults.standard.bool(forKey: shouldTrackCustomExitEventsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: shouldTrackCustomExitEventsKey)
        }
    }
    
    /**
     * Enables creation of Urban Airship RegionEvents when Gimbal place events are detected.
     */
    @objc open var shouldTrackRegionEvents : Bool {
        get {
            return UserDefaults.standard.bool(forKey: shouldTrackRegionEventsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: shouldTrackRegionEventsKey)
        }
    }
    
    #if !targetEnvironment(simulator)
    private override init() {
        placeManager = PlaceManager()
        gimbalDelegate = AirshipGimbalDelegate()
        deviceAttributesManager = DeviceAttributesManager()
        placeManager.delegate = gimbalDelegate

        super.init();

        // Hide the BLE power status alert to prevent duplicate alerts
        if (UserDefaults.standard.value(forKey: hideBlueToothAlertViewKey) == nil) {
            UserDefaults.standard.set(true, forKey: hideBlueToothAlertViewKey)
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AirshipGimbalAdapter.updateDeviceAttributes),
                                               name: Channel.channelCreatedEvent,
                                               object: nil)
    }
    #endif

    /**
     * Restores the adapter. Should be called in didFinishLaunchingWithOptions.
     */
    @objc open func restore() {
        updateDeviceAttributes()
    }

    /**
     * Starts the adapter.
     * @param apiKey The Gimbal API key.
     */
    @objc open func start(_ apiKey: String?) {
        #if !targetEnvironment(simulator)
        guard let key = apiKey else {
            print("Unable to start Gimbal Adapter, missing key")
            return
        }

        Gimbal.setAPIKey(key, options: nil)
        Gimbal.start()
        updateDeviceAttributes()
        print("Started Gimbal Adapter. Gimbal application instance identifier: \(Gimbal.applicationInstanceIdentifier() ?? "⚠️ Empty Gimbal application instance identifier")")
        #endif
    }

    /**
     * Stops the adapter.
     */
    @objc open func stop() {
        #if !targetEnvironment(simulator)
        Gimbal.stop()
        print("Stopped Gimbal Adapter");
        #endif
    }

    @objc private func updateDeviceAttributes() {
        #if !targetEnvironment(simulator)
        var deviceAttributes = Dictionary<AnyHashable, Any>()

        if (deviceAttributesManager.getDeviceAttributes().count > 0) {
            for (key,val) in deviceAttributesManager.getDeviceAttributes() {
                deviceAttributes[key] = val
            }
        }
        
        deviceAttributes["ua.nameduser.id"] = Airship.contact.namedUserID
        deviceAttributes["ua.channel.id"] = Airship.channel.identifier

        if (deviceAttributes.count > 0) {
            deviceAttributesManager.setDeviceAttributes(deviceAttributes)
        }

        let identifiers = Airship.analytics.currentAssociatedDeviceIdentifiers()
        identifiers.set(identifier: Gimbal.applicationInstanceIdentifier(), key: "com.urbanairship.gimbal.aii")
        Airship.analytics.associateDeviceIdentifiers(identifiers)
        #endif
    }
}

#if !targetEnvironment(simulator)
private class AirshipGimbalDelegate : NSObject, PlaceManagerDelegate {
    private let source: String = "Gimbal"
    private let keyBoundaryEvent = "boundaryEvent"
    private let customEntryEventName = "gimbal_custom_entry_event"
    private let customExitEventName = "gimbal_custom_exit_event"
    
    private var shouldCreateCustomEntryEvent : Bool {
        get {
            return UserDefaults.standard.bool(forKey: shouldTrackCustomEntryEventsKey)
        }
    }
    private var shouldCreateCustomExitEvent : Bool {
        get {
            return UserDefaults.standard.bool(forKey: shouldTrackCustomExitEventsKey)
        }
    }
    private var shouldCreateRegionEvents : Bool {
        get {
            return UserDefaults.standard.bool(forKey: shouldTrackRegionEventsKey)
        }
    }

    func placeManager(_ manager: PlaceManager, didBegin visit: Visit) {
        trackPlaceEventFor(visit, boundaryEvent: .enter)
        
        AirshipGimbalAdapter.shared.delegate?.placeManager?(manager, didBegin: visit)
    }

    func placeManager(_ manager: PlaceManager, didBegin visit: Visit, withDelay delayTime: TimeInterval) {
        trackPlaceEventFor(visit, boundaryEvent: .enter)
        
        AirshipGimbalAdapter.shared.delegate?.placeManager?(manager, didBegin: visit, withDelay: delayTime)
    }

    func placeManager(_ manager: PlaceManager, didEnd visit: Visit) {
        trackPlaceEventFor(visit, boundaryEvent: .exit)
        
        AirshipGimbalAdapter.shared.delegate?.placeManager?(manager, didEnd: visit)
    }

    func placeManager(_ manager: PlaceManager, didReceive sighting: BeaconSighting, forVisits visits: [Any]) {
        AirshipGimbalAdapter.shared.delegate?.placeManager?(manager, didReceive: sighting, forVisits: visits)
    }

    func placeManager(_ manager: PlaceManager, didDetect location: CLLocation) {
        AirshipGimbalAdapter.shared.delegate?.placeManager?(manager, didDetect: location)
    }
    
    private func trackPlaceEventFor(_ visit: Visit, boundaryEvent: UABoundaryEvent) {
        if shouldCreateRegionEvents,
           let regionEvent = RegionEvent(regionID: visit.place.identifier,
                                           source: source,
                                    boundaryEvent: boundaryEvent) {
            Airship.analytics.addEvent(regionEvent)
        }

        if boundaryEvent == .enter, shouldCreateCustomEntryEvent {
            createAndTrackEvent(withName: customEntryEventName, forVisit: visit, boundaryEvent: boundaryEvent)
        } else if boundaryEvent == .exit, shouldCreateCustomExitEvent {
            createAndTrackEvent(withName: customExitEventName, forVisit: visit, boundaryEvent: boundaryEvent)
        }
    }
    
    private func createAndTrackEvent(withName eventName: String,
                                     forVisit visit: Visit,
                                     boundaryEvent: UABoundaryEvent) {
        // create event properties
        var visitProperties:[String : Any] = [:]
        visitProperties["visitID"] = visit.visitID
        visitProperties["placeIdentifier"] = visit.place.identifier
        visitProperties["placeName"] = visit.place.name
        visitProperties["source"] = source
        visitProperties["boundaryEvent"] = boundaryEvent.rawValue
        var placeAttributes = Dictionary<String, Any>()
        for attributeKey in visit.place.attributes.allKeys() {
            if let value = visit.place.attributes.string(forKey: attributeKey) {
                placeAttributes[attributeKey] = value
                visitProperties.updateValue(value, forKey: "GMBL_PA_\(attributeKey)")
            }
        }
        visitProperties["placeAttributes"] = placeAttributes
        if boundaryEvent == .exit {
            visitProperties["dwellTimeInSeconds"] = visit.dwellTime
        }
        
        let event = CustomEvent(name: eventName)
        event.properties = visitProperties
        event.track()
    }
}
#endif
