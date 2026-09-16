import 'dart:async';

import '../../services/backend_service.dart';


class HomeRealtimeHandler {

  final BackendService backend;


  final void Function()
  onAuthenticated;


  final void Function()
  onAuthError;


  final void Function(
      Map<String, dynamic> data,
      )
  onNewTrip;


  final void Function()
  onConnectionError;


  final void Function()
  onConnectionDone;


  StreamSubscription<Map<String, dynamic>>?
  _subscription;


  HomeRealtimeHandler({

    required this.backend,

    required this.onAuthenticated,

    required this.onAuthError,

    required this.onNewTrip,

    required this.onConnectionError,

    required this.onConnectionDone,

  });


  void start() {

    _subscription =
        backend
            .connectRealtime()
            .listen(

              (event) {

            final type =
            event['type']
                ?.toString();


            // ========================================
            // BACKEND YEU CAU AUTH
            // ========================================

            if (
            type ==
                'auth_required'
            ) {

              return;
            }


            // ========================================
            // DA XAC THUC
            // ========================================

            if (
            type ==
                'authenticated'
            ) {

              onAuthenticated();

              return;
            }


            // ========================================
            // AUTH THAT BAI
            // ========================================

            if (
            type ==
                'auth_error'
            ) {

              onAuthError();

              return;
            }


            // ========================================
            // KHONG PHAI CUOC MOI
            // ========================================

            if (
            type !=
                'new_trip'
            ) {

              return;
            }


            // ========================================
            // DU LIEU CUOC
            // ========================================

            final rawData =
            event['data'];


            if (
            rawData is! Map
            ) {

              return;
            }


            final data =
            Map<String, dynamic>.from(
              rawData,
            );


            onNewTrip(
              data,
            );
          },


          onError:
              (
              error,
              ) {

            onConnectionError();
          },


          onDone:
              () {

            onConnectionDone();
          },
        );
  }


  void dispose() {

    _subscription
        ?.cancel();


    _subscription =
    null;


    backend.disconnect();
  }
}