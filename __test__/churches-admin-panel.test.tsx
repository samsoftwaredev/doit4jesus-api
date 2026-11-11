import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import ChurchesAdminPanel from '../src/components/admin/ChurchesAdminPanel';

const mockReplace = jest.fn();
let mockChurchView: string | null = null;

jest.mock('next/navigation', () => ({
  useRouter: () => ({ replace: mockReplace }),
  useSearchParams: () => ({ get: () => mockChurchView }),
}));
jest.mock('../src/components/admin/ChurchScheduleReviewsPanel', () => ({
  __esModule: true,
  default: function ScheduleReviewsPanelStub() {
    return <div>Schedule reviews panel</div>;
  },
}));
jest.mock('../src/components/admin/AddChurchPanel', () => ({
  __esModule: true,
  default: function AddChurchPanelStub() {
    return <div>Add church panel</div>;
  },
}));

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

describe('ChurchesAdminPanel', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    jest.clearAllMocks();
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(async () => {
    await act(async () => root.unmount());
    container.remove();
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = false;
  });

  async function renderPanel() {
    await act(async () =>
      root.render(
        <ChurchesAdminPanel
          token="admin-token"
          onClose={jest.fn()}
          changeRequests={<div>Change requests panel</div>}
        />,
      ),
    );
  }

  it('shows the change requests view by default with three tabs', async () => {
    mockChurchView = null;
    await renderPanel();

    expect(container.textContent).toContain('Change requests panel');
    expect(
      Array.from(container.querySelectorAll('[role="tab"]')).map(
        (tab) => tab.textContent,
      ),
    ).toEqual(['Change Requests', 'Schedule Reviews', 'Add Church']);
  });

  it('renders the Add Church view from the churchView parameter', async () => {
    mockChurchView = 'add';
    await renderPanel();

    expect(container.textContent).toContain('Add church panel');
    expect(container.textContent).not.toContain('Change requests panel');
  });

  it('navigates to the Add Church view when its tab is selected', async () => {
    mockChurchView = 'schedules';
    await renderPanel();
    expect(container.textContent).toContain('Schedule reviews panel');

    const addTab = Array.from(container.querySelectorAll('[role="tab"]')).find(
      (tab) => tab.textContent === 'Add Church',
    );
    await act(async () => {
      addTab?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });

    expect(mockReplace).toHaveBeenCalledWith(
      '/dashboard?tab=admin&panel=churches&churchView=add',
    );
  });
});
