///  Spectrum.swift
///  MuVis
///
/// This view renders a visualization of the simple one-dimensional spectrum (using a mean-square amplitude scale) of the music. However, the horizontal scale is
/// rendered logarithmically to account for the logarithmic relationship between spectrum bins and musical octaves.  The spectrum covers 6 octaves from
/// leftFreqC1 = 32 Hz to rightFreqB8 = 2033 Hz -  that is from bin = 12 to bin = 755.
///
/// In the lower plot, the vertical axis shows (in red) the mean-square amplitude of the instantaneous spectrum of the audio being played. The red peaks are spectral
/// lines depicting the harmonics of the musical notes being played. The blue curve is a smoothed average of the red curve (computed by the findMean function
/// within the SpectralEnhancer class).  The blue curve typically represents percussive effects which smear spectral energy over a broad range.
///
/// The upper plot (in green) is the same as the lower plot except the vertical scale is decibels (over an 80 dB range) instead of the mean-square amplitude.
/// This more closely represents what the human ear actually hears.
///
///  https://stackoverflow.com/questions/61225841/environmentobject-not-found-for-child-shape-in-swiftui
///
/// Created by Keith Bromley on 4 Nov 2021. Animated in Aug 2022.

import SwiftUI


struct MusicSpectrum: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        
        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (settings.selectedColorScheme == .dark) ? Color.black : Color.white
        
        ZStack {
            if(settings.optionOn) {
                GrayVertRectangles(columnCount: 72)             // struct code in VisUtilities file
                NoteNames(rowCount: 2, octavesPerRow: 6) }      // struct code in VisUtilities file
            MusicSpectrum_Live()
        }
        .background( (settings.optionOn) ? Color.clear : backgroundColor )
    }
}



struct MusicSpectrum_Live: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var spectralEnhancer = SpectralEnhancer()
    var peaksSorter = PeaksSorter()
    
    var body: some View {
        
        // Convert the observed array-of-Floats into an AnimatableVector:
        let spectrumA = AnimatableVector(values: audioManager.spectrum)
        let meanSpectrum = AnimatableVector(values: spectralEnhancer.findMean(inputArray: audioManager.spectrum))
        let decibelSpectrum = AnimatableVector(values: ampToDecibels(inputArray: audioManager.spectrum))
        let decibelSpectrum_Floats: [Float] = [Float](ampToDecibels(inputArray: audioManager.spectrum))
        let meanDecibelSpectrum = AnimatableVector(values: spectralEnhancer.findMean(inputArray: decibelSpectrum_Floats))

        // First, render the rms amplitude spectrum in red in the lower half pane:
        MusicSpectrum_Shape(settings: self._settings, lower: true, vector: spectrumA)
            .stroke(Color(red: 1.0, green: 0.0, blue: 0.0), lineWidth: 2)
            .animation(Animation.linear, value: spectrumA)

        // Second, render the mean of the rms amplitude spectrum in blue:
        MusicSpectrum_Shape(settings: self._settings, lower: true, vector: meanSpectrum)
            .stroke(Color(red: 0.0, green: 0.0, blue: 1.0), lineWidth: 2)
            .animation(Animation.linear, value: meanSpectrum)
        
        // Third, render the decibel-scale spectrum in green in the upper half pane:
        MusicSpectrum_Shape(settings: self._settings, lower: false, vector: decibelSpectrum)
            .stroke(Color(red: 0.0, green: 1.0, blue: 0.0), lineWidth: 2)
            .animation(Animation.linear, value: decibelSpectrum)
        
        // Fourth, render the mean of the decibel-scale spectrum in blue:
        MusicSpectrum_Shape(settings: self._settings, lower: false, vector: meanDecibelSpectrum)
            .stroke(Color(red: 0.0, green: 0.0, blue: 1.0), lineWidth: 2)
            .animation(Animation.linear, value: meanDecibelSpectrum)
        
        // Fifth, optionally render the peaks in black at the top of the view:
        ForEach( 0 ..< PeaksSorter.peakCount, id: \.self) { peakNum in        //  0 <= peakNum < 16
            MusicSpectrumPeaks_View()
        }
    }
}



struct MusicSpectrum_Shape: Shape {
    @EnvironmentObject var settings: Settings
    var lower: Bool                     // If lower==true then render in the lower half pane.
    var vector: AnimatableVector        // Declare a variable called vector of type Animatable vector
    
    public var animatableData: AnimatableVector {
        get { vector }
        set { vector = newValue }
    }
    
    public func path(in rect: CGRect) -> Path {
        let width: Double  = rect.width
        let height: Double = rect.height
        var x : Double = 0.0       // The drawing origin is in the upper left corner.
        var y : Double = 0.0       // The drawing origin is in the upper left corner.
        let halfHeight: Double = height * 0.5

        let bottomBin: Int = settings.octBottomBin[0]	// bottomBin = 12
        let topBin: Int = settings.octTopBin[5]         // topBin  =  755
        
        var magY: Double = 0.0             // used as a preliminary part of the "y" value
        
        var path = Path()
        path.move(to: CGPoint( x: 0.0, y:  lower ? height : halfHeight) )

        for bin in bottomBin ... topBin {
            x = width * settings.binXFactor6[bin]

            magY = Double( vector[bin] ) * halfHeight
            magY = min(max(0.0, magY), halfHeight)
            y = lower ? height - magY : halfHeight - magY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}



struct MusicSpectrumPeaks_View: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var peaksSorter = PeaksSorter()
    
    var body: some View {
        Canvas { context, size in
            let width: Double  = size.width
            let height: Double = size.height
            let halfHeight: Double = height * 0.5

            var x : Double = 0.0
            
            if(settings.optionOn) {
                for peakNum in 0 ..< PeaksSorter.peakCount {   // peaksSorter.peakCount = 16
                    x = width * settings.binXFactor6[audioManager.peakBinNumbers[peakNum]]

                    var path = Path()
                    path.move(to:    CGPoint( x: x, y: 0.0 ) )
                    path.addLine(to: CGPoint( x: x, y: 0.1 * halfHeight ) )
                    context.stroke( path,
                                     with: .color((settings.selectedColorScheme == .light) ? Color.black : Color.white),
                                     lineWidth: 2.0 )
                    path = Path()
                    path.move(to:    CGPoint( x: x, y: halfHeight ) )
                    path.addLine(to: CGPoint( x: x, y: 1.1 * halfHeight ) )
                    context.stroke( path,
                                    with: .color((settings.selectedColorScheme == .light) ? Color.black : Color.white),
                                    lineWidth: 2.0 )
                }
            }
        }
    }
}
