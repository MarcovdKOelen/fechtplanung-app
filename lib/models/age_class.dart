enum AgeClass { u13, u15, u17, u20 }

String ageClassLabel(AgeClass a) {
  switch (a) {
    case AgeClass.u13:
      return "U13";
    case AgeClass.u15:
      return "U15";
    case AgeClass.u17:
      return "U17";
    case AgeClass.u20:
      return "U20";
  }
}
