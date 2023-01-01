/// MuSpectrum.swift
/// MuVis
///
/// This view renders a visualization of the muSpectrum (using a mean-square amplitude scale) of the music. I have coined the name muSpectrum for the
/// exponentially-resampled version of the spectrum to more closely represent the notes of the musical scale.
///
/// In the lower plot, the horizontal axis is exponential frequency - from the note C1 (about 33 Hz) on the left to the note B6 (about 1,976 Hz) on the right.
/// The vertical axis shows (in red) the mean-square amplitude of the instantaneous muSpectrum of the audio being played. The red peaks are spectral lines
/// depicting the harmonics of the musical notes being played - and cover six octaves. The blue curve is a smoothed average of the red curve (computed by the
/// findMean function within the SpectralEnhancer class). The blue curve typically represents percussive effects which smear spectral energy over a broad range.
///
/// In the upper plot, the green curve is simply the red curve after subtracting the blue curve. This green curve would be a good starting point for analyzing the
/// harmonic structure of an ensemble of notes being played to facilitate automated note detection.
///
///  https://stackoverflow.com/questions/61225841/environmentobject-not-found-for-child-shape-in-swiftui
///
/// Created by Keith Bromley on 20 Nov 2020.  Significantly updated on 30 Oct 2021.  Animated in Aug 2022.

import SwiftUI

struct MuSpectrum: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        
        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (settings.selectedColorScheme == .dark) ? Color.black : Color.white
        
        ZStack {
            if(settings.optionOn) {
                GrayVertRectangles(columnCount: 72)                 // struct code in VisUtilities file
                NoteNames(rowCount: 2, octavesPerRow: 6) }          // struct code in VisUtilities file
            MuSpectrum_Live()
        }
        .background( (settings.optionOn) ? Color.clear : backgroundColor )
    }
}



struct MuSpectrum_Live: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var spectralEnhancer = SpectralEnhancer()
    var peaksSorter = PeaksSorter()
    
    var body: some View {
        
        // Convert the observed array-of-Floats into an AnimatableVector:
        let muSpectrumA = AnimatableVector(values: audioManager.muSpectrum)
        let meanMuSpectrum = AnimatableVector(values: spectralEnhancer.findMean(inputArray: audioManager.muSpectrum))
        let enhancedMuSpectrum = AnimatableVector(values: spectralEnhancer.enhance(inputArray: audioManager.muSpectrum))

        // First, render the muSpectrum in red in the lower half pane:
        // MuSpectrum_Shape(settings: self._settings, lower: true, vector: muSpectrumA)
        MuSpectrum_Shape(lower: true, vector: muSpectrumA)
            .stroke(Color(red: 1.0, green: 0.0, blue: 0.0), lineWidth: 2)
            .animation(Animation.linear, value: muSpectrumA)

        // Second, render the mean of the muSpectrum in blue in the lower half pane:
        MuSpectrum_Shape(lower: true, vector: meanMuSpectrum)
            .stroke(Color(red: 0.0, green: 0.0, blue: 1.0), lineWidth: 2)
            .animation(Animation.linear, value: meanMuSpectrum)

        // Third, render the enhanced muSpectrum in green in the upper half pane:
        // The enhancedMuSpectrum is just the muSpectrum with the meanMuSpectrum subtracted from it.
        MuSpectrum_Shape(lower: false, vector: enhancedMuSpectrum)
            .stroke(Color(red: 0.0, green: 1.0, blue: 0.0), lineWidth: 2)
            .animation(Animation.linear, value: enhancedMuSpectrum)

        // Fourth, optionally render the peaks in black at the top of the view:
        ForEach( 0 ..< PeaksSorter.peakCount, id: \.self) { peakNum in        //  0 <= peakNum < 16
            MuSpectrumPeaks_View()
        }
    }
}



struct MuSpectrum_Shape: Shape {
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

        var upRamp: Double = 0.0
        var magY: Double = 0.0         // used as a preliminary part of the "y" value
        
        var path = Path()
        path.move(to: CGPoint( x: 0.0, y: lower ? height : halfHeight ) )
            
        for point in 0 ..< sixOctPointCount {
            // upRamp goes from 0.0 to 1.0 as point goes from 0 to sixOctPointCount:
            upRamp =  Double(point) / Double(sixOctPointCount)
            x = upRamp * width
            
            magY = Double(vector[point]) * halfHeight
            magY = min(max(0.0, magY), halfHeight)
            y = lower ? height - magY : halfHeight - magY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}



struct MuSpectrumPeaks_View: View {
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
                for peakNum in 0 ..< PeaksSorter.peakCount {                            // peaksSorter.peakCount = 16
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
