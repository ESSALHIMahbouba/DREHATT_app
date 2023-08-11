import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mymeds_app/screens/add_medication1.dart';

class Mediaction extends StatefulWidget {
  const Mediaction({super.key});

  @override
  State<Mediaction> createState() => _MediactionState();
}

class _MediactionState extends State<Mediaction> {
  // final user = FirebaseAuth.instance.currentUser;

  //bottom nav bar
  int _selectedIndex = 1;

  /*Floating Action Button should reutrn add_medication1.dart file method
  and the method should return the floating action button.*/
  //Floating Action Button
  bool isFABvisible = true;
  returnFAB() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddMedication1(),
          ),
        );
      },
      child: const Icon(Icons.add),
      backgroundColor: Color.fromARGB(255, 146, 191, 199),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medication',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),

        leading: IconButton(
          icon: const Icon(
            Icons.search,
            color: Colors.black,
          ),
          padding: const EdgeInsets.only(left: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.black,
            ),
            padding: const EdgeInsets.only(right: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddMedication1(),
                ),
              );
            },
          ),
        ],
        // backgroundColor: Color.fromARGB(163, 206, 240, 247)
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //medication gif
                    Image.asset(
                      'lib/assets/images/medication.gif',
                    ),
                  ],
                ),
                //title
                Text(
                  'Medication',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                //reminder text
                Text(
                  'You currently have no reminders',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}