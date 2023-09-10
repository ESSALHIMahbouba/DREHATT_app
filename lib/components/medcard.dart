import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timeline_calendar/timeline/model/datetime.dart';
import 'package:mymeds_app/components/time_line.dart';
import 'package:shimmer/shimmer.dart';

class MedCard extends StatelessWidget {
  final String documentID;
  final int index;
  final int size;
  late CalendarDateTime selectedDate;

  MedCard(
      {super.key,
      required this.documentID,
      required this.index,
      required this.size,
      required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    //get the collection
    CollectionReference medications = FirebaseFirestore.instance
        .collection('Users')
        .doc(currentUser!.email)
        .collection('Medications');

    return FutureBuilder(
      future:
          medications.doc(documentID).get(GetOptions(source: Source.server)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            Map<String, dynamic>? med_data = snapshot.data!.data() != null
                ? snapshot.data!.data() as Map<String, dynamic>
                : <String, dynamic>{};

            return Column(
              children: [
                // Text('Medication name: ${data['medname']}'),
                // Text('Dosage: ${data['strength']} ${data['strength_unit']}'),
                // Text('Frequency: ${data['frequency']}'),
                // Text('$selectedDate'),
                // Text('Taken? : ${data['isTaken']}'),

                FutureBuilder(
                  future: medications
                      .doc(documentID)
                      .collection('Logs')
                      .doc('$selectedDate')
                      .get(const GetOptions(source: Source.server)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      if (snapshot.hasData) {
                        Map<String, dynamic>? log_data =
                            snapshot.data!.data() != null
                                ? snapshot.data!.data() as Map<String, dynamic>
                                : <String, dynamic>{};

                        // print(snapshot.data!.data());
                        if (snapshot.data!.data() == null) {
                          // print('No medications for ${selectedDate}');
                        } else {
                          // print('${log_data['isTaken']}');
                          // print(
                          // '${med_data['medname']} ${med_data['strength']} ${med_data['strength_unit']}');
                          return TimeLine(
                            isFirst: index == 0 ? true : false,
                            isLast: index == size - 1,
                            isPast: true,
                            medName: med_data['medname'],
                            dosage:
                                '${med_data['strength']} ${med_data['strength_unit']}',
                            time: med_data['times'],
                            isTaken: log_data['isTaken'],
                          );
                        }
                      }
                    }
                    return Container(
                      width: double.infinity,
                      height: 120.0,
                      margin: const EdgeInsets.fromLTRB(50, 20, 25, 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        color: Colors.grey.shade300,
                      ),
                    );
                  },
                )
              ],
            );
          } else if (snapshot.hasError) {
            return Container(
              width: double.infinity,
              height: 120.0,
              margin: const EdgeInsets.fromLTRB(50, 20, 25, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                color: Colors.grey.shade300,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.signal_wifi_off_rounded,
                      color: Colors.grey.shade600),
                  const SizedBox(
                    width: 20,
                  ),
                  Text(
                    'Network Error',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              enabled: true,
              child: const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    BannerPlaceholder(),
                  ],
                ),
              ));
        }
        // return Center(child: CircularProgressIndicator());
        return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            enabled: true,
            child: const SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  BannerPlaceholder(),
                ],
              ),
            ));
      },
    );
  }
}

class BannerPlaceholder extends StatelessWidget {
  const BannerPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120.0,
      margin: const EdgeInsets.fromLTRB(50, 20, 25, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        color: Colors.white,
      ),
    );
  }
}
