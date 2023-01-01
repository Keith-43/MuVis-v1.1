///  Spectrum6.swift
///  MuVis
///
/// This view renders a visualization of the simple one-dimensional spectrum (using a mean-square amplitude scale) of the music.
///
/// We could render a full Spectrum - that is, rendering all of the 8,192 bins -  covering a frequency range from 0 Hz on the left to about 44,100 / 2 = 22,050 Hz
/// on the right . But instead, we will render the spectrum bins from 12 to 755 - that is the 6 octaves from 32 Hz to 2,033 Hz.
///
/// In the lower plot, the horizontal axis is linear frequency (from 32 Hz on the left to 2,033 Hz on the right). The vertical axis shows (in red) the mean-square
/// amplitude of the instantaneous spectrum of the audio being played. The red peaks are spectral lines depicting the harmonics of the musical notes
/// being played. The blue curve is a smoothed average of the red curve (computed by the findMean function within the SpectralEnhancer class).
/// The blue curve typically represents percussive effects which smear spectral energy over a broad range.
///
/// The upper plot (in green) is the same as the lower plot except the vertical scale is decibels (over an 80 dB range) instead of the mean-square amplitude.
/// This more closely represents what the human ear actually hears.
///
///  https://stackoverflow.com/questions/61225841/environmentobject-not-found-for-child-shape-in-swiftui
///  
/// Created by Keith Bromley on 20 Nov 2020.  Significantly updated on 28 Oct 2021.

import SwiftUI
import Accelerate


struct Spectrum: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        
        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (settings.selectedColorScheme == .dark) ? Color.black : Color.white
        
        ZStack {
            if(settings.optionOn) { GrayVertRects() }
            Spectrum_Live()
        }
        .background( (settings.optionOn) ? Color.clear : backgroundColor )
    }
}

            

struct GrayVertRects: View {
    @EnvironmentObject var settings: Settings

    var body: some View {
        Canvas { context, size in
            let width: Double  = size.width
            let height: Double = size.height
            
            //                               C      C#    D      D#     E     F      F#    G      G#    A      A#    B
            let accidentalNote: [Bool] = [  false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false ]
            let octaveCount = 6
            for oct in 0 ..< octaveCount {              //  0 <= oct < 6
                for note in 0 ..< notesPerOctave {      // notesPerOctave = 12
                
                    let cumulativeNotes: Int = oct * notesPerOctave + note  // cumulativeNotes = 0, 1, 2, 3, ... 71
                    
                    if(accidentalNote[cumulativeNotes] == true) {
                        // This condition selects the column values for the notes C#, D#, F#, G#, and A#
                
                        let leftNoteFreq: Float  = settings.leftFreqC1  * pow(settings.twelfthRoot2, Float(cumulativeNotes) )
                        let rightFreqC1: Float   = settings.freqC1 * settings.twentyFourthRoot2
                        let rightNoteFreq: Float = rightFreqC1 * pow(settings.twelfthRoot2, Float(cumulativeNotes) )
                        
                        // The x-axis is frequency (in Hz) and covers the 6 octaves from 32 Hz to 2,033 Hz.
                        var x: Double = width * ( ( Double(leftNoteFreq) - 32.0 ) / (2033.42 - 32.0) )
                
                        var path = Path()
                        path.move(   to: CGPoint( x: x, y: height ) )
                        path.addLine(to: CGPoint( x: x, y: 0.0))
                        
                        x = width * ( ( Double(rightNoteFreq) - 32.0 ) / (2033.42 - 32.0) )
                        
                        path.addLine(to: CGPoint( x: x, y: 0.0))
                        path.addLine(to: CGPoint( x: x, y: height))
                        path.closeSubpath()
                    
                        context.fill( path,
                                      with: .color( (settings.selectedColorScheme == .light) ?
                                                    Color.lightGray.opacity(0.25) :
                                                    Color.black.opacity(0.25) ) )
                        /*
                        context.stroke( path,
                                        with: .color( Color.black),
                                        lineWidth: 1.0 )
                        */
                    }
                }  // end of for() loop over note
            }  // end of for() loop over oct
        }
    }
}



struct Spectrum_Live: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var spectralEnhancer = SpectralEnhancer()
    var peaksSorter = PeaksSorter()
    
    var body: some View {
        
        // Convert the observed array-of-Floats into an AnimatableVector:
        let spectrumA = AnimatableVector(values: audioManager.spectrum)
        let meanSpectrum = AnimatableVector(values: spectralEnhancer.findMean(inputArray: audioManager.spectrum))
        let decibelSpectrum = AnimatableVector(values: ampToDecibels(inputArray: audioManager.spectrum) )
        let decibelSpectrum_Floats: [Float] = [Float]( ampToDecibels(inputArray: audioManager.spectrum) )
        let meanDecibelSpectrum = AnimatableVector(values: spectralEnhancer.findMean(inputArray: decibelSpectrum_Floats))

        // First, render the rms amplitude spectrum in red in the lower half pane:
        Spectrum_Shape(settings: self._settings, lower: true, vector: spectrumA)
            .stroke(Color(red: 1.0, green: 0.0, blue: 0.0), lineWidth: 2)
            .animation(Animation.linear, value: spectrumA)
        
        // Second, render the mean of the rms amplitude spectrum in blue:
        Spectrum_Shape(settings: self._settings, lower: true, vector: meanSpectrum)
            .stroke(Color(red: 0.0, green: 0.0, blue: 1.0), lineWidth: 2)
            .animation(Animation.linear, value: meanSpectrum)
        
        // Third, render the decibel-scale spectrum in green in the upper half pane:
        Spectrum_Shape(settings: self._settings, lower: false, vector: decibelSpectrum)
            .stroke(Color(red: 0.0, green: 1.0, blue: 0.0), lineWidth: 2)
            .animation(Animation.linear, value: decibelSpectrum)
        
        // Fourth, render the mean of the decibel-scale spectrum in blue:
        Spectrum_Shape(settings: self._settings, lower: false, vector: meanDecibelSpectrum)
            .stroke(Color(red: 0.0, green: 0.0, blue: 1.0), lineWidth: 2)
            .animation(Animation.linear, value: meanDecibelSpectrum)
        
        // Fifth, optionally render the peaks in black at the top of the view:
        ForEach( 0 ..< PeaksSorter.peakCount, id: \.self) { peakNum in        //  0 <= peakNum < 16
            Peaks_View()
        }
    }
}

    

struct Spectrum_Shape: Shape {
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

        // We will render the spectrum bins from 12 to 755 - that is the 6 octaves from 32 Hz to 2,033 Hz.
        let lowerBin: Int = settings.octBottomBin[0]    // render the spectrum bins from 12 to 755
        let upperBin: Int = settings.octTopBin[5]       // render the spectrum bins from 12 to 755
        
        var upRamp: Double = 0.0
        var magY: Double = 0.0      // used as a preliminary part of the "y" value
        
        var path = Path()
        path.move(to: CGPoint( x: 0.0, y: lower ? height : halfHeight ) )

        for bin in lowerBin ... upperBin {
            // upRamp goes from 0.0 to 1.0 as bin goes from lowerBin to upperBin:
            upRamp =  Double(bin - lowerBin) / Double(upperBin - lowerBin)
            x = upRamp * width

            magY = Double(vector[bin]) * halfHeight
            magY = min(max(0.0, magY), halfHeight)
            y = lower ? height - magY : halfHeight - magY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}



struct Peaks_View: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var peaksSorter = PeaksSorter()
    
    var body: some View {
        Canvas { context, size in
            let width: Double  = size.width
            let height: Double = size.height
            let halfHeight: Double = height * 0.5

            var x : Double = 0.0
            
            let lowerBin: Int = settings.octBottomBin[0]    // render the spectrum bins from 12 to 755
            let upperBin: Int = settings.octTopBin[5]       // render the spectrum bins from 12 to 755
            
            if(settings.optionOn) {

                for peakNum in 0 ..< PeaksSorter.peakCount {   // peaksSorter.peakCount = 16
                     x = width * ( Double(audioManager.peakBinNumbers[peakNum] - lowerBin) / Double(upperBin - lowerBin) )

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


// The ampToDecibels() func is used in the Spectrum6 and MusicSpectrum6 visualizations.
public func ampToDecibels(inputArray: [Float]) -> ([Float]) {
    var dB: Float = 0.0
    let dBmin: Float =  1.0 + 0.0125 * 20.0 * log10(0.001)
    var amplitude: Float = 0.0
    var outputArray: [Float] = [Float] (repeating: 0.0, count: inputArray.count)

    // I must raise 10 to the power of -4 to get my lowest dB value (0.001) to 20*(-4) = 80 dB
    for bin in 0 ..< inputArray.count {
        amplitude = inputArray[bin]
        if(amplitude < 0.001) { amplitude = 0.001 }
        dB = 20.0 * log10(amplitude)    // As 0.001  < spectrum < 1 then  -80 < dB < 0
        dB = 1.0 + 0.0125 * dB          // As 0.001  < spectrum < 1 then    0 < dB < 1
        dB = dB - dBmin
        dB = min(max(0.0, dB), 1.0)
        outputArray[bin] = dB           // We use this array below in creating the mean spectrum
    }
    return outputArray
}
