package com.example.geo_logistica

import android.graphics.Color
import android.os.Bundle
import android.os.Build
import android.view.View
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Fondo crema oficial de la marca antes de que Flutter dibuje su primer frame
        window.decorView.setBackgroundColor(Color.parseColor("#FBF9F8"))
        
        // Desactiva Autofill a nivel de ventana para evitar el botón flotante de 3 líneas del Credential Manager en Android 13/14+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        }
        
        super.onCreate(savedInstanceState)
    }
}
