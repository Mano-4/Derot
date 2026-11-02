//
//  PickSomethingElse.swift
//  Derot
//
//  What the "Pick something else" button on an activity's first screen does.
//  Whoever shows the activity (the library, or a pause notification) puts an
//  action here, and the button runs it to swap in another random activity.
//  If nobody set one, the button just closes the activity like before.
//

import SwiftUI

extension EnvironmentValues {
    // nil = no swap available, so "Pick something else" closes the activity.
    @Entry var pickSomethingElse: (() -> Void)? = nil
}
