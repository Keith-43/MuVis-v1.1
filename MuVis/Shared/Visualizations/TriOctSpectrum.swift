/// TriOctSpectrum.swift
/// MuVis
///
/// The TriOctSpectrum visualization is similar to the Music Spectrum visualization in that it shows a spectrum of six octaves of the audio waveform -
/// however it renders it as two separate spectrum displays.
///
/// It has the format of a downward-facing spectrum in the lower half-screen covering the lower three octaves, and an upward-facing spectrum in the upper
/// half-screen covering the upper three octaves. Each half-screen shows three octaves. (The name "bi- tri-octave spectrum" seemed unduly cumbersome,
/// so I abbreviated it to "tri-octave spectrum"). The specific note frequencies are:
///
/// *         262 Hz                                   523 Hz                                    1046 Hz                            1976 Hz
/// *          C4                                          C5                                           C6                                       B6
/// *           |                                               |                                               |                                          |
/// *          W B W B W W B W B W B W W B W B W W B W B W B W W B W B W W B W B W B W
/// *
/// *          W B W B W W B W B W B W W B W B W W B W B W B W W B W B W W B W B W B W
/// *           |                                               |                                               |                                          |
/// *          C1                                          C2                                            C3                                      B3
/// *          33Hz                                   65 Hz                                       130 Hz                               247 Hz
///
/// *  Using sampleRate = 11,025 and binCount = 2048, we get (binFreqWidth = (11,025/2)/2,048 = 2.69165 Hz
///
///         bottomBin = 95        <---- triOctaveBinCount = 661 ---->               topBin = 755
///         leftFreq = 254.1776 Hz                                                  rightFreq = 2033.4207 Hz
///         |                                                                       |
///         C4 = 262 Hz           C5 = 523 Hz             C6 = 1046 Hz            B6 = 1976 Hz
///         |                     |                       |                       |
///         W B W B W W B W B W B W W B W B W W B W B W B W W B W B W W B W B W B W
///
///         W B W B W W B W B W B W W B W B W W B W B W B W W B W B W W B W B W B W
///         |                     |                       |                       |
///         C1 = 33 Hz           C2 = 65 Hz               C3 = 130 Hz             B3 = 247 Hz
///         |                                                                       |
///         leftFreq = 31.7722 Hz                                                   rightFreq = 254.1776 Hz
///         bottomBin = 12        <---- triOctaveBinCount = 83 ---->                topBin = 94
///
/// As with the LinearOAS visualization, the spectral peaks comprising each note are a separate color, and the colors of the grid are consistent across all octaves -
/// hence all octaves of a "C" note are red; all octaves of an "E" note are green, and all octaves of a "G" note are light blue, etc.
/// Also, we have added a piano-keyboard overlay to clearly differentiate the black notes (in gray) from the white notes (in white).
/// Also, we have added note names for the white notes at the top and bottom.
///
/// The visual appearance of these two spectra is of each note being rendered as a small blob of a different color. However, in fact, we implement this effect by
/// having static vertical blocks depicting the note colors and then having the non-spectrum rendered as two big white / darkGray blobs covering the non-spectrum
/// portion of the spectrum display - one each for the upper-half-screen and the lower-half-screen. The static colored vertical blocks are rendered first; then the
/// dynamic white / darkGray big blobs; then the gray "piano black notes"; and finally the note names.
///
/// Created by Keith Bromley on 29/  Nov 2020.   Significantly updated on 17 Nov 2021.  Animated in Aug 2022.


import SwiftUI


struct TriOctSpectrum: View {
    @EnvironmentObject var settings: Settings
    var body: some View {
        ZStack {
            ColorRectangles(columnCount: 36)                        // struct code in VisUtilities file
            DoubleSpectrum_Live()
            if(settings.optionOn) {
                GrayVertRectangles(columnCount: 36)                 // struct code in VisUtilities file
                VerticalLines(columnCount: 36)                      // struct code in VisUtilities file
                HorizontalLines(rowCount: 2, offset: 0.0)           // struct code in VisUtilities file
                NoteNames(rowCount: 2, octavesPerRow: 3)            // struct code in VisUtilities file
            }
        }
    }
}



struct DoubleSpectrum_Live : View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        
        // Convert the observed array-of-Floats into an AnimatableVector:
        let spectrumA = AnimatableVector(values: audioManager.spectrum)
        
        ForEach( 0 ... 1, id: \.self) { rowNum in        //  rowNum = 0, 1
            DoubleSpectrum_Live_Shape(vector: spectrumA, row: rowNum )
                .environmentObject(Settings.settings)
                .foregroundColor( (settings.selectedColorScheme == .light) ? Color.white : Color.darkGray )
                .animation(Animation.linear, value: spectrumA)
        }
    }
}
    
    
    
struct DoubleSpectrum_Live_Shape: Shape {
    
    @EnvironmentObject var settings: Settings
    var vector: AnimatableVector        // Declare a variable called vector of type Animatable vector
    var row: Int
    
    public var animatableData: AnimatableVector {
        get { vector }
        set { vector = newValue }
    }
    
    public func path(in rect: CGRect) -> Path {
        let width: Double  = rect.width
        let height: Double = rect.height
        let halfHeight : Double = height * 0.5
        var x : Double = 0.0       // The drawing origin is in the upper left corner.
        var y : Double = 0.0       // The drawing origin is in the upper left corner.
        var magY: Double = 0.0     // used as a preliminary part of the "y" value
        let octavesPerRow : Int = 3
        let octaveWidth: Double = width / Double(octavesPerRow)
        
        var path = Path()
        
        // Render lower 3 octaves in the bottom halfpane, and the upper 3 octaves in the upper halfplane:
        if (row == 0) {
            path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
            path.addLine( to: CGPoint( x: width, y: height))        // right bottom
            path.addLine( to: CGPoint( x: 0.0,   y: height))        // left bottom
            path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
        } else {
            path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
            path.addLine( to: CGPoint( x: width, y: 0.0))           // right top
            path.addLine( to: CGPoint( x: 0.0,   y: 0.0))           // left top
            path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
        }
        
        for oct in 0 ... 2 {
            let newOct: Int = (row==0) ? oct : 3 + oct
        
            for bin in settings.octBottomBin[newOct] ... settings.octTopBin[newOct] {
                x = ( Double(oct) * octaveWidth ) + ( settings.binXFactor[bin] * octaveWidth )
                magY = Double(vector[bin]) * halfHeight
                magY = min(max(0.0, magY), halfHeight)
                y = (row == 0) ? halfHeight + magY : halfHeight - magY
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.addLine( to: CGPoint( x: width, y: halfHeight ) )
        path.closeSubpath()
        return path
        
    }  // end of path() func
    
}  // end of DoubleSpectrum_Live{} struct
