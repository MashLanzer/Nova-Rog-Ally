// Worker de la palabra de activacion, en C#.
//
// POR QUE C# Y NO PowerShell:
// PowerShell NO puede manejar los eventos asincronos de SAPI. El manejador se
// ejecuta en el hilo del reconocedor y corrompe el runspace: mata el proceso
// en silencio, sin excepcion ni linea de log. Se comprobo dos veces, primero
// dentro del asistente (se lo llevaba por delante) y luego en un worker
// aislado de PowerShell (moria igual, aunque ya sin arrastrar al asistente).
//
// La version sincrona de PowerShell si era estable, pero Recognize() abre el
// microfono al llamar y lo CIERRA al volver, dejando huecos sordos entre
// ciclos: se perdian las activaciones que caian en ese hueco.
//
// En C# los eventos son nativos: microfono continuo Y estabilidad.
//
// COMPILAR:
//   csc /target:exe /out:wake_worker.exe /r:System.Speech.dll wake_worker.cs
//
// USO:
//   wake_worker.exe <nombre> <confianza> <rutaMarca> <rutaLog>

using System;
using System.Globalization;
using System.IO;
using System.Speech.Recognition;
using System.Threading;

class WakeWorker
{
    static string rutaMarca;
    static string rutaLog;
    static double umbral;
    static readonly object candado = new object();

    static void Anota(string mensaje)
    {
        if (string.IsNullOrEmpty(rutaLog)) { return; }
        try
        {
            lock (candado)
            {
                File.AppendAllText(rutaLog,
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  [escucha] " + mensaje + "\r\n",
                    new System.Text.UTF8Encoding(false));
            }
        }
        catch { }
    }

    static int Main(string[] args)
    {
        string nombre = args.Length > 0 ? args[0] : "nova";
        umbral = args.Length > 1 ? double.Parse(args[1], CultureInfo.InvariantCulture) : 0.3;
        rutaMarca = args.Length > 2 ? args[2] : "despierta.flag";
        rutaLog = args.Length > 3 ? args[3] : "";

        SpeechRecognitionEngine motor;
        try
        {
            motor = new SpeechRecognitionEngine(new CultureInfo("es-ES"));

            // Gramatica CERRADA: solo el nombre y sus variantes. Cuanto mas
            // cerrada, menos falsos disparos: el motor no tiene con que
            // confundirse.
            Choices opciones = new Choices();
            opciones.Add(nombre);
            opciones.Add("oye " + nombre);
            opciones.Add("hola " + nombre);
            opciones.Add("ey " + nombre);
            opciones.Add(nombre + " escucha");
            opciones.Add(nombre + " por favor");

            GrammarBuilder constructor = new GrammarBuilder();
            constructor.Culture = new CultureInfo("es-ES");
            constructor.Append(opciones);
            motor.LoadGrammar(new Grammar(constructor));

            motor.SpeechRecognized += delegate (object emisor, SpeechRecognizedEventArgs ev)
            {
                double c = Math.Round(ev.Result.Confidence, 2);
                if (ev.Result.Confidence >= umbral)
                {
                    Anota("ACTIVADO por '" + ev.Result.Text + "' (confianza " + c + ")");
                    try { File.WriteAllText(rutaMarca, DateTime.Now.ToString("o")); } catch { }
                }
                else
                {
                    Anota("descartado '" + ev.Result.Text + "' (confianza " + c + ", minimo " + umbral + ")");
                }
            };

            // Los rechazos son la unica pista util cuando "no detecta nada".
            motor.SpeechRecognitionRejected += delegate (object emisor, SpeechRecognitionRejectedEventArgs ev)
            {
                if (ev.Result != null && !string.IsNullOrEmpty(ev.Result.Text))
                {
                    Anota("rechazado '" + ev.Result.Text + "' (confianza " +
                          Math.Round(ev.Result.Confidence, 2) + ")");
                }
            };

            motor.SetInputToDefaultAudioDevice();
            motor.RecognizeAsync(RecognizeMode.Multiple);
            Anota("worker C# en marcha: nombre='" + nombre + "' confianza minima=" + umbral +
                  " (microfono continuo)");
        }
        catch (Exception e)
        {
            Anota("ERROR al iniciar: " + e.Message);
            return 1;
        }

        // El hilo principal solo vigila. Con el microfono abierto de forma
        // continua, AudioLevel SI refleja lo que entra: un nivel 0 sostenido
        // significa que no llega senal, y eso ya es un diagnostico.
        int nivelMax = 0;
        while (true)
        {
            for (int i = 0; i < 60; i++)
            {
                Thread.Sleep(500);
                if (motor.AudioLevel > nivelMax) { nivelMax = motor.AudioLevel; }
            }
            Anota("pulso: estado=" + motor.AudioState + " nivel maximo en 30 s=" + nivelMax);
            nivelMax = 0;
        }
    }
}
