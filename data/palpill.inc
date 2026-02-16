{ Pill palette data extracted from PALPILL.$00, $01, $02 }

const
  Palpill000Data: array[0..279] of Byte = (
    $C0, $C4, $C8, $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0,
    $C4, $C8, $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0, $C4,
    $C8, $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0, $C4, $C8,
    $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0, $C4, $C8, $CC, $D0, $C0, $C4, $C8, $CC,
    $D0, $C0, $C4, $C8, $CC, $D0, $C1, $C5, $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1,
    $C1, $C5, $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C1,
    $C5, $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C1, $C5,
    $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C1, $C5, $C9,
    $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C1, $C5, $C9, $CD, $D1, $C2, $C6, $CA, $CE,
    $D2, $C2, $C6, $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2,
    $C2, $C6, $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2, $C2,
    $C6, $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2, $C2, $C6,
    $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2, $C2, $C6, $CA, $CE, $D2, $C2, $C6, $CA,
    $CE, $D2, $C3, $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF,
    $D3, $C3, $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3,
    $C3, $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3, $C3,
    $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3, $C3, $C7,
    $CB, $CF, $D3, $C3, $C7, $CB, $CF, $D3
  );

const
  Palpill001Data: array[0..279] of Byte = (
    $D4, $D8, $DC, $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4,
    $D8, $DC, $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4, $D8,
    $DC, $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4, $D8, $DC,
    $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4, $D8, $DC, $E0, $E4, $D4, $D8, $DC, $E0,
    $E4, $D4, $D8, $DC, $E0, $E4, $D5, $D9, $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5,
    $D5, $D9, $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D5,
    $D9, $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D5, $D9,
    $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D5, $D9, $DD,
    $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D5, $D9, $DD, $E1, $E5, $D6, $DA, $DE, $E2,
    $E6, $D6, $DA, $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6,
    $D6, $DA, $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6, $D6,
    $DA, $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6, $D6, $DA,
    $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6, $D6, $DA, $DE, $E2, $E6, $D6, $DA, $DE,
    $E2, $E6, $D7, $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3,
    $E7, $D7, $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7,
    $D7, $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7, $D7,
    $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7, $D7, $DB,
    $DF, $E3, $E7, $D7, $DB, $DF, $E3, $E7
  );

const
  Palpill002Data: array[0..279] of Byte = (
    $E8, $EC, $F0, $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8,
    $EC, $F0, $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8, $EC,
    $F0, $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8, $EC, $F0,
    $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8, $EC, $F0, $F4, $F8, $E8, $EC, $F0, $F4,
    $F8, $E8, $EC, $F0, $F4, $F8, $E9, $ED, $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9,
    $E9, $ED, $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9, $E9,
    $ED, $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9, $E9, $ED,
    $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9, $E9, $ED, $F1,
    $F5, $F9, $E9, $ED, $F1, $F5, $F9, $E9, $ED, $F1, $F5, $F9, $EA, $EE, $F2, $F6,
    $FA, $EA, $EE, $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA,
    $EA, $EE, $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA, $EA,
    $EE, $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA, $EA, $EE,
    $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA, $EA, $EE, $F2, $F6, $FA, $EA, $EE, $F2,
    $F6, $FA, $EB, $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7,
    $FB, $EB, $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB,
    $EB, $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB, $EB,
    $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB, $EB, $EF,
    $F3, $F7, $FB, $EB, $EF, $F3, $F7, $FB
  );

