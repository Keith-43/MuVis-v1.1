/// Harmonograph.swift
/// MuVis
///
/// I have long sought to develop a music-visualization scheme that readily displays the harmonic relationship of the frequencies being played. My inspiration comes
/// from Lissajous figures generated by applying sinusoidal waveforms to the vertical and horizontal inputs of an oscilloscope. Inputs of the same frequency generate
/// elliptical curves (including circles and lines). Inputs of different frequencies, where one is an integer multiple of the other, generate "twisted" ellipses.
/// A frequency ratio of 3:1 produces a "twisted ellipse" with 3 major lobes. A frequency ratio of 5:4 produces a curve with 5 horizontal lobes and 4 vertical lobes.
/// Such audio visualizations are both aesthetically pleasing and highly informative.
///
/// Over the past several years, I have implemented many many such visualizations and applied them to analyzing music. Unfortunately, most suffered from being
/// overly complex, overly dynamic, and uninformative. In my humble opinion, this Harmonograph visualization strikes the right balance between simplicity (i.e., the
/// ability to appreciate the symmetry of harmonic relationships) and dynamics that respond promptly to the music.
///
/// The wikipedia article at https://en.wikipedia.org/wiki/Harmonograph describes a double pendulum apparatus, called a Harmonograph, that creates
/// Lissajous figures from mixing two sinusoidal waves of different frequencies and phases. This Harmonograph visualization uses just the two loudest spectrum
/// peaks to produce the Lissajous figure. That is, the loudest peak generates a sine wave of its frequency to drive the horizontal axis of our visual oscilloscope,
/// and the second-loudest peak generates a sine wave of its frequency to drive the vertical axis.
///
/// For a pleasing effect, the Harmonograph Lissajous figure is rendered on top of a slightly-dimmed simplified TriOctSpectrum visualization.
///
/// Created by Keith Bromley in Nov 2020.   Significantly updated in Nov 2021 and again in Aug 2022.

import SwiftUI


struct Harmonograph: View {
    var body: some View {
        ZStack {
            Harmonograph_DoubleSpectrum()
            LissajousFigure()
        }
    }
}



struct Harmonograph_DoubleSpectrum : View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    static var colorIndexA: Int = 0
    
    var body: some View {
    
        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (settings.selectedColorScheme == .dark) ? Color.black : Color.white
    
         Canvas { context, size in

            let width: Double  = size.width
            let height: Double = size.height
            let halfHeight : Double = height * 0.5
            var x : Double = 0.0       // The drawing origin is in the upper left corner.
            var y : Double = 0.0       // The drawing origin is in the upper left corner.
            var magY: Double = 0.0     // used as a preliminary part of the "y" value
            let octavesPerRow : Int = 3
            let octaveWidth: Double = width / Double(octavesPerRow)


// ---------------------------------------------------------------------------------------------------------------------
            // Before rendering any live data, let's paint the underlying graphics layer with a time-varying color:
            
            let colorSize: Int = 500    // This determines the frequency of the color change over time.
            var hue:  Double = 0.0
            
            var path = Path()
            path.move   ( to: CGPoint( x: 0.0,  y: 0.0   ) )        // top left
            path.addLine( to: CGPoint( x: width,y: 0.0   ) )        // top right
            path.addLine( to: CGPoint( x: width,y: height) )        // bottom right
            path.addLine( to: CGPoint( x: 0.0,  y: height) )        // bottom left
            path.addLine( to: CGPoint( x: 0.0,  y: 0.0   ) )        // top left
            path.closeSubpath()
            
            settings.colorIndex = (settings.colorIndex >= colorSize) ? 0 : settings.colorIndex + 1
            hue = Double(settings.colorIndex) / Double(colorSize)          // 0.0 <= hue < 1.0
             
            context.fill( path,
                          with: .color(Color(hue: hue, saturation: 1.0, brightness: 0.7) ) )
                          // Deliberately slightly dim to serve as background
                          
// ---------------------------------------------------------------------------------------------------------------------
            // Render a black/white blob over the lower half-pane but exposing the spectrum of the lower three octaves:
            var bottomPath = Path()
            bottomPath.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
            bottomPath.addLine( to: CGPoint( x: width, y: height))        // right bottom
            bottomPath.addLine( to: CGPoint( x: 0.0,   y: height))        // left bottom
            bottomPath.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
            
            for oct in 0 ..< 3 {        // oct = 0, 1, 2
                for bin in settings.octBottomBin[oct] ... settings.octTopBin[oct] {
                    x = ( Double(oct) * octaveWidth ) + ( settings.binXFactor[bin] * octaveWidth )
                    magY = Double(audioManager.spectrum[bin]) * halfHeight
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight + magY
                    bottomPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            bottomPath.addLine( to: CGPoint( x: width, y: halfHeight ) )
            bottomPath.closeSubpath()
            context.fill( bottomPath,
                          with: .color( backgroundColor) )

        
// ---------------------------------------------------------------------------------------------------------------------
            // Render a black/white blob over the upper half-pane but exposing the spectrum of the upper three octaves:
            var topPath = Path()
            topPath.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
            topPath.addLine( to: CGPoint( x: width, y: 0.0))           // right top
            topPath.addLine( to: CGPoint( x: 0.0,   y: 0.0))           // left top
            topPath.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint

            for oct in 3 ..< 6 {        // oct = 3, 4, 5
                for bin in settings.octBottomBin[oct] ... settings.octTopBin[oct] {                     // 
                    x = ( Double(oct-3) * octaveWidth ) + ( settings.binXFactor[bin] * octaveWidth )
                    magY = Double(audioManager.spectrum[bin]) * halfHeight
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight - magY
                    topPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            topPath.addLine( to: CGPoint( x: width, y: halfHeight ) )
            topPath.closeSubpath()
            context.fill( topPath,
                          with: .color( backgroundColor) )
       
        }  // end of Canvas{}
        .background( (settings.optionOn) ? Color.clear : backgroundColor )
        
    }  // end of var body: some View{}
}  // end of Harmonograph2_DoubleSpectrum{} struct


// ---------------------------------------------------------------------------------------------------------------------
// Render the Lissajous figure.
struct LissajousFigure : View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var peaksSorter = PeaksSorter()
    
    var body: some View {
        Canvas { context, size in

            let width: Double  = size.width
            let height: Double = size.height
            let halfWidth : Double  = width * 0.5
            let halfHeight : Double = height * 0.5
    
            var x : Double = 0.0       // The drawing origin is in the upper left corner.
            var y : Double = 0.0       // The drawing origin is in the upper left corner.
            
            let now = Date()  // Contains the date and time of the start of each frame of audio data.
            let seconds:Double = now.timeIntervalSinceReferenceDate

            var period: Double = 1.0
            var angle: Double = 0.0
            var oldAngle: Double = 0.0
            var dataLength: Int = 0
            
            // Get the sortedPeakBinNumbers for our 6-octave spectrum:
            let lowerBin: Int = settings.octBottomBin[0]    // lowerBin =  12   bin12  has frequency =   32 Hz
            let midBin:   Int = settings.octBottomBin[3]    // midBin =    95   bin95  has frequency =  254 Hz
            let upperBin: Int = settings.octTopBin[5]       // upperBin = 755   bin755 has frequency = 2033 Hz

            // Render a Lissajous figure from the loudest two peaks in either the lower or upper 3 octaves:
            
            if (settings.optionOn == false) {   // This renders a Lissajous figure for 2 peaks in bottom 3 octaves.
            
                let result = peaksSorter.getSortedPeaks( binValues: audioManager.spectrum,
                                                         bottomBin: lowerBin,
                                                         topBin: midBin-1,
                                                         peakThreshold: 0.1)
                let sortedPeakBinNumbers = result.sortedPeakBinNumbers
                let sortedPeakAmplitudes = result.sortedPeakAmplitudes

                dataLength = 1000                   // Looks aesthetically pleasing
                
                // Generate a sinusoidal waveform for the loudest peak:
                period = AudioManager.sampleRate / ( Double(sortedPeakBinNumbers[0]) * AudioManager.binFreqWidth )
                oldAngle = seconds / period
                var waveform0: [Double] = Array(repeating: 0.0, count: dataLength)
                
                for i in 0 ..< dataLength {
                    angle = oldAngle + ( 2.0 * Double.pi * Double(i) / period )
                    waveform0[i] = 0.2 * Double(sortedPeakAmplitudes[0]) * sin(angle)
                }

                // Generate a sinusoidal waveform for the next-to-loudest peak:
                period = AudioManager.sampleRate / ( Double(sortedPeakBinNumbers[1]) * AudioManager.binFreqWidth )
                oldAngle = seconds / period
                var waveform1: [Double] = Array(repeating: 0.0, count: dataLength)
                
                for i in 0 ..< dataLength {
                    angle = oldAngle + ( 2.0 * Double.pi * Double(i) / period )
                    waveform1[i] = 0.2 * Double(sortedPeakAmplitudes[1]) * sin(angle)
                }

                // Generate a Lissajous figure from the two waveforms for peaks 0 and 1:
                var path = Path()
                x = halfWidth  + (halfWidth  * waveform0[0])   // x coordinate of the zeroth sample
                y = halfHeight - (halfHeight * waveform1[0])   // y coordinate of the zeroth sample
                path.move( to: CGPoint( x: x, y: y ) )

                for sampleNum in 1 ..< dataLength {
                    x = halfWidth  + (halfWidth  * waveform0[sampleNum])
                    y = halfHeight - (halfHeight * waveform1[sampleNum])
                    x = min(max(0, x), width)
                    y = min(max(0, y), height)
                    path.addLine( to: CGPoint( x: x, y: y ) )
                }
                context.stroke( path,
                                with: .color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0),
                                lineWidth: 4.0 )

            }else{                              // This renders a Lissajous figure for 2 peaks in top 3 octaves.

                let result = peaksSorter.getSortedPeaks( binValues: audioManager.spectrum,
                                                         bottomBin: midBin,
                                                         topBin: upperBin,
                                                         peakThreshold: 0.1)
                let sortedPeakBinNumbers = result.sortedPeakBinNumbers
                let sortedPeakAmplitudes = result.sortedPeakAmplitudes

                dataLength = 400                   // Looks aesthetically pleasing
                
                // Generate a sinusoidal waveform for the loudest peak:
                period = AudioManager.sampleRate / ( Double(sortedPeakBinNumbers[0]) * AudioManager.binFreqWidth )
                oldAngle = seconds / period
                var waveform0: [Double] = Array(repeating: 0.0, count: dataLength)
                
                for i in 0 ..< dataLength {
                    angle = oldAngle + ( 2.0 * Double.pi * Double(i) / period )
                    waveform0[i] = 0.3 * Double(sortedPeakAmplitudes[0]) * sin(angle)
                }

                // Generate a sinusoidal waveform for the next-to-loudest peak:
                period = AudioManager.sampleRate / ( Double(sortedPeakBinNumbers[1]) * AudioManager.binFreqWidth )
                oldAngle = seconds / period
                var waveform1: [Double] = Array(repeating: 0.0, count: dataLength)
                
                for i in 0 ..< dataLength {
                    angle = oldAngle + ( 2.0 * Double.pi * Double(i) / period )
                    waveform1[i] = 0.3 * Double(sortedPeakAmplitudes[1]) * sin(angle)
                }

                // Generate a Lissajous figure from the two waveforms for peaks 0 and 1:
                var path = Path()
                x = halfWidth  + (halfWidth  * waveform0[0])   // x coordinate of the zeroth sample
                y = halfHeight - (halfHeight * waveform1[0])   // y coordinate of the zeroth sample
                path.move( to: CGPoint( x: x, y: y ) )

                for sampleNum in 1 ..< dataLength {
                    x = halfWidth  + (halfWidth  * waveform0[sampleNum])
                    y = halfHeight - (halfHeight * waveform1[sampleNum])
                    x = min(max(0, x), width)
                    y = min(max(0, y), height)
                    path.addLine( to: CGPoint( x: x, y: y ) )
                }
                context.stroke( path,
                                with: .color(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0),
                                lineWidth: 4.0 )
            }

            
            
            // Print on-screen the elapsed duration-per-frame (in milliseconds) (typically about 50)
            if(showMSPF == true) {
                let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                context.draw(Text("MSPF: \( settings.monitorPerformance() )"), in: frame )
            }

        }  // end of Canvas{}
    }  // end of var body: some View{}
}  // end of LissajousFigure{} struct



struct Harmonograph_Previews: PreviewProvider {
    static var previews: some View {
        Harmonograph()
    }
}
