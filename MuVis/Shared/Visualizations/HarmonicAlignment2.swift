/// HarmonicAlignment2.swift
/// MuVis
///
/// The HarmonicAlignment2 visualization depicts the same information as the HarmonicAlignment visualization but rendered in a slightly different form.
/// (This is purely for aesthetic effect - which you may find pleasing or annoying.) The muSpectrum for each of the six octaves (and for each of the six harmonics
/// within each octave) is rendered twice - one upward stretching muSpectrum and one downward stretching muSpectrum.
///
/// The OAS of the fundamental notes (in red) is rendered first. Then the OAS of the first harmonic notes (in yellow) are rendered over it.
/// Then the OAS of the second harmonic notes (in green) are rendered over it, and so on - until all 6 harmonics are depicted.
///
/// If the optionOn button is pressed, we multiply the value of the harmonics (harm = 2 through 6) by the value of the fundamental (harm = 1).
/// So, the harmonics are shown if-and-only-if there is meaningful energy in the fundamental.
///
/// Created by Keith Bromley on 20 Nov 2020.   Significantly updated on 17 Nov 2021.  Animated in Aug 2022.


import SwiftUI


struct HarmonicAlignment2: View {

    var body: some View {
        ZStack {
            GrayVertRectangles(columnCount: 12)                         // struct code in VisUtilities file
            HorizontalLines(rowCount: 6, offset: 0.5)                   // struct code in VisUtilities file
            VerticalLines(columnCount: 12)                              // struct code in VisUtilities file
            NoteNames(rowCount: 2, octavesPerRow: 1)                    // struct code in VisUtilities file
            HarmonicAlignment2_Live()
        }
    }
}



struct HarmonicAlignment2_Live: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    let harmonicCount: Int = 6  // The total number of harmonics rendered.    0 <= har <= 5     1 <= harm <= 6
    let rowCount: Int = 6
    
    var body: some View {
        
        // Convert the observed array-of-Floats into an AnimatableVector:
        let muSpectrumA = AnimatableVector(values: audioManager.muSpectrum)
        
        ForEach( 0 ..< harmonicCount, id: \.self) { harmonic in             //  0 <= harmonic < 6
            
            let hueHarmOffset: Double = 1.0 / ( Double(harmonicCount) )     //  hueHarmOffset = 1/6
            let hueIndex: Double = Double(harmonic) * hueHarmOffset         //  hueIndex = 0, 1/6, 2/6, 3/6, 4/6, 5/6
            
            ForEach( 0 ..< rowCount, id: \.self) { rowNum in                //  0 <= rowNum < 6
                
                HarmonicAlignment2_Live_Shape(vector: muSpectrumA, har: harmonic, row: rowNum)
                    .environmentObject(Settings.settings)
                    .animation(Animation.linear(duration: 0.1), value: muSpectrumA)
                    .foregroundColor( Color( hue: hueIndex, saturation: 1.0, brightness: 1.0 ) )
                    .animation(Animation.linear, value: muSpectrumA)
            }
        }
    }
}



struct HarmonicAlignment2_Live_Shape: Shape {
    @EnvironmentObject var settings: Settings

    var vector: AnimatableVector        // Declare a variable called vector of type Animatable vector
    var har: Int                        // har  = 0,1,2,3,4,5      harm = 1,2,3,4,5,6
    var row: Int
    
    public var animatableData: AnimatableVector {
        get { vector }
        set { vector = newValue }
    }
              
    func path(in rect: CGRect) -> Path {
    
        let width: Double  = rect.width
        let height: Double = rect.height
        /*
        This is a two-dimensional grid containing 6 row and 12 columns.
        Each of the 6 rows contains 1 octave or 12 notes or 12*12 = 144 points.
        Each of the 12 columns contains 6 octaves of that particular note.
        The entire grid renders 6 octaves or 6*12 = 72 notes or 6*144 = 864 points
        */

        // let harmonicCount: Int = 6  // The total number of harmonics rendered.    0 <= har <= 5     1 <= harm <= 6
        
        var x: Double = 0.0       // The drawing origin is in the upper left corner.
        var y: Double = 0.0       // The drawing origin is in the upper left corner.
        var upRamp: Double = 0.0

        let rowCount: Int = 6  // The FFT provides 7 octaves (plus 5 unrendered notes)
        let rowHeight: Double = height / Double(rowCount)
        let halfRowHeight: Double = 0.5 * rowHeight
        
        var magY:  Double = 0.0        // used as a preliminary part of the "y" value
        var cumulativePoints: Int = 0
        var harmAmp: Double = 0.0   // harmonic amplitude is a scale factor to decrease the rendered value of harmonics
        
        let harmIncrement: [Int]  = [ 0, 12, 19, 24, 28, 31 ]      // The increment (in notes) for the six harmonics:
        //                           C1  C2  G2  C3  E3  G3
                    
        let rowD: Double = Double(row)

        var path = Path()
        path.move( to: CGPoint( x: 0.0, y: height - rowD * rowHeight - halfRowHeight ) )

        for point in 0 ..< pointsPerOctave {
            // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
            upRamp =  Double(point) / Double(pointsPerOctave)
            x = upRamp * width

            cumulativePoints = row * pointsPerOctave + point
            magY = Double(vector[cumulativePoints])
            
            if(settings.optionOn == true) {
                harmAmp = (har==0) ? 1.0 : magY  // This gracefully reduces the harmonic spectra for weak fundamentals
            } else {
                harmAmp = 1.0
            }
            cumulativePoints = row * pointsPerOctave + pointsPerNote*harmIncrement[har] + point
            if(cumulativePoints >= totalPointCount) { cumulativePoints = totalPointCount-1 }
            magY = 0.2 * Double(vector[cumulativePoints]) * rowHeight * harmAmp
            
            if( cumulativePoints == totalPointCount-1 ) { magY = 0 }
            magY = min(max(0.0, magY), rowHeight)  // Limit over- and under-saturation.
            y = height - rowD * rowHeight - halfRowHeight - magY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine( to: CGPoint( x: width, y: height - rowD * rowHeight - halfRowHeight ) )
        
        for point in (0 ..< pointsPerOctave).reversed() {
            upRamp =  Double(point) / Double(pointsPerOctave)
            x = upRamp * width
            
            cumulativePoints = row * pointsPerOctave + point
            magY = Double(vector[cumulativePoints])
            
            if(settings.optionOn == true) {
                harmAmp = (har==0) ? 1.0 : magY  // This gracefully reduces the harmonic spectra for weak fundamentals
            } else {
                harmAmp = 1.0
            }
            cumulativePoints = row * pointsPerOctave + pointsPerNote*harmIncrement[har] + point
            if(cumulativePoints >= totalPointCount) { cumulativePoints = totalPointCount-1 }
            magY = 0.2 * Double(vector[cumulativePoints]) * rowHeight * harmAmp
            
            if( cumulativePoints == totalPointCount-1 ) { magY = 0 }
            magY = min(max(0.0, magY), rowHeight)  // Limit over- and under-saturation.
            y = height - rowD * rowHeight - halfRowHeight + magY
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine( to: CGPoint( x: 0.0,   y: height - rowD * rowHeight - halfRowHeight ) )
        path.closeSubpath()
        return path
        
    }
            
}  // end of HarmonicAlignment2_Live_Shape struct
