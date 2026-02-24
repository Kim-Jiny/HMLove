/**
 * 생년월일로 별자리(서양 점성술) 계산
 */
export function getZodiacSign(birthDate) {
  const date = new Date(birthDate);
  const month = date.getMonth() + 1;
  const day = date.getDate();

  const signs = [
    { name: '염소자리', start: [1, 1], end: [1, 19] },
    { name: '물병자리', start: [1, 20], end: [2, 18] },
    { name: '물고기자리', start: [2, 19], end: [3, 20] },
    { name: '양자리', start: [3, 21], end: [4, 19] },
    { name: '황소자리', start: [4, 20], end: [5, 20] },
    { name: '쌍둥이자리', start: [5, 21], end: [6, 21] },
    { name: '게자리', start: [6, 22], end: [7, 22] },
    { name: '사자자리', start: [7, 23], end: [8, 22] },
    { name: '처녀자리', start: [8, 23], end: [9, 22] },
    { name: '천칭자리', start: [9, 23], end: [10, 22] },
    { name: '전갈자리', start: [10, 23], end: [11, 21] },
    { name: '사수자리', start: [11, 22], end: [12, 21] },
    { name: '염소자리', start: [12, 22], end: [12, 31] },
  ];

  for (const sign of signs) {
    const [sm, sd] = sign.start;
    const [em, ed] = sign.end;
    if ((month === sm && day >= sd) || (month === em && day <= ed)) {
      return sign.name;
    }
  }

  return '염소자리';
}

/**
 * 생년월일로 띠(십이지) 계산
 */
export function getChineseZodiac(birthDate) {
  const date = new Date(birthDate);
  const year = date.getFullYear();

  const animals = [
    '원숭이', '닭', '개', '돼지',
    '쥐', '소', '호랑이', '토끼',
    '용', '뱀', '말', '양',
  ];

  return animals[year % 12] + '띠';
}
