/**
 * 기념일 계산 유틸리티
 * - 100일 단위 (100~1000)
 * - N주년 (1~20)
 * - 생일
 */

/**
 * 특정 월에 해당하는 자동 기념일 목록 반환 (캘린더용)
 * @param {Object} couple - couple 객체 (startDate, users[{nickname, birthDate}])
 * @param {number} year
 * @param {number} month - 1~12
 * @returns {Array<{id, title, date, isAnniversary, repeatType, description, color, eventType, _auto}>}
 */
export function getAutoAnniversariesForMonth(couple, year, month) {
  const autoEvents = [];
  const start = new Date(couple.startDate);

  // 100일 단위
  for (let d = 100; d <= 1000; d += 100) {
    const ms = start.getTime() + (d - 1) * 86400000;
    const date = new Date(ms);
    if (date.getUTCFullYear() === year && date.getUTCMonth() === month - 1) {
      autoEvents.push({
        id: `auto-${d}`,
        title: `${d}일`,
        date: new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())),
        isAnniversary: true,
        repeatType: 'NONE',
        description: null,
        color: null,
        eventType: 'anniversary',
        _auto: true,
      });
    }
  }

  // N주년
  for (let y = 1; y <= 20; y++) {
    const date = new Date(Date.UTC(start.getUTCFullYear() + y, start.getUTCMonth(), start.getUTCDate()));
    if (date.getUTCFullYear() === year && date.getUTCMonth() === month - 1) {
      autoEvents.push({
        id: `auto-y${y}`,
        title: `${y}주년`,
        date,
        isAnniversary: true,
        repeatType: 'NONE',
        description: null,
        color: null,
        eventType: 'anniversary',
        _auto: true,
      });
    }
  }

  // 생일
  for (const user of couple.users) {
    if (user.birthDate) {
      const birth = new Date(user.birthDate);
      if (birth.getUTCMonth() === month - 1) {
        autoEvents.push({
          id: `auto-bday-${user.nickname}`,
          title: `${user.nickname} 생일`,
          date: new Date(Date.UTC(year, month - 1, birth.getUTCDate())),
          isAnniversary: true,
          repeatType: 'YEARLY',
          description: null,
          color: null,
          eventType: 'anniversary',
          _auto: true,
        });
      }
    }
  }

  return autoEvents;
}

/**
 * 향후 maxDays 이내의 다가오는 기념일 배열 반환 (리마인드 스케줄러용)
 * @param {Object} couple - couple 객체 (startDate, users[{nickname, birthDate}])
 * @param {number} maxDays - 최대 며칠 이내까지 확인할지
 * @returns {Array<{title: string, date: Date, daysLeft: number}>}
 */
export function getUpcomingAnniversaries(couple, maxDays = 30) {
  const now = new Date();
  const todayUTC = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const results = [];
  const start = new Date(couple.startDate);

  // 100일 단위
  for (let d = 100; d <= 1000; d += 100) {
    const ms = start.getTime() + (d - 1) * 86400000;
    const date = new Date(ms);
    const dateUTC = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
    const daysLeft = Math.round((dateUTC - todayUTC) / 86400000);
    if (daysLeft >= 0 && daysLeft <= maxDays) {
      results.push({ title: `${d}일`, date: new Date(dateUTC), daysLeft });
    }
  }

  // N주년
  for (let y = 1; y <= 20; y++) {
    const date = new Date(Date.UTC(start.getUTCFullYear() + y, start.getUTCMonth(), start.getUTCDate()));
    const dateUTC = date.getTime();
    const daysLeft = Math.round((dateUTC - todayUTC) / 86400000);
    if (daysLeft >= 0 && daysLeft <= maxDays) {
      results.push({ title: `${y}주년`, date: new Date(dateUTC), daysLeft });
    }
  }

  // 생일 (올해 또는 내년)
  const thisYear = now.getUTCFullYear();
  for (const user of couple.users) {
    if (user.birthDate) {
      const birth = new Date(user.birthDate);
      for (const yr of [thisYear, thisYear + 1]) {
        const date = new Date(Date.UTC(yr, birth.getUTCMonth(), birth.getUTCDate()));
        const dateUTC = date.getTime();
        const daysLeft = Math.round((dateUTC - todayUTC) / 86400000);
        if (daysLeft >= 0 && daysLeft <= maxDays) {
          results.push({ title: `${user.nickname} 생일`, date: new Date(dateUTC), daysLeft });
        }
      }
    }
  }

  return results;
}
